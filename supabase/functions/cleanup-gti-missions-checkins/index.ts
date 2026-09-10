import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const MAX_AGE_MS = 24 * 60 * 60 * 1000;
const MIN_RUN_GAP_MS = 10 * 60 * 1000;

Deno.serve(async (req: Request) => {
  const headers = { "content-type": "application/json", "cache-control": "no-store" };
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "method_not_allowed" }), { status: 405, headers });
  }

  const url = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !serviceKey) {
    return new Response(JSON.stringify({ error: "server_config" }), { status: 500, headers });
  }

  const supabase = createClient(url, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  try {
    const { data: state, error: stateError } = await supabase
      .from("gti_missions_cleanup_state")
      .select("last_run_at")
      .eq("singleton", true)
      .maybeSingle();
    if (stateError) throw stateError;

    const lastRun = state?.last_run_at ? new Date(state.last_run_at).getTime() : 0;
    if (lastRun && Date.now() - lastRun < MIN_RUN_GAP_MS) {
      return new Response(JSON.stringify({ ok: true, skipped: "throttled" }), { status: 200, headers });
    }

    const { error: lockError } = await supabase
      .from("gti_missions_cleanup_state")
      .update({ last_run_at: new Date().toISOString() })
      .eq("singleton", true);
    if (lockError) throw lockError;

    const bucket = supabase.storage.from("gti-missions-checkins");
    const cutoffMs = Date.now() - MAX_AGE_MS;
    const expired: string[] = [];

    async function scan(prefix = "", depth = 0): Promise<void> {
      if (depth > 4) return;
      let offset = 0;
      while (true) {
        const { data, error } = await bucket.list(prefix, {
          limit: 100,
          offset,
          sortBy: { column: "name", order: "asc" },
        });
        if (error) throw error;
        if (!data?.length) break;

        for (const item of data) {
          const path = prefix ? `${prefix}/${item.name}` : item.name;
          if (item.id) {
            const stamp = item.created_at || item.updated_at;
            if (stamp && new Date(stamp).getTime() <= cutoffMs) expired.push(path);
          } else {
            await scan(path, depth + 1);
          }
        }

        if (data.length < 100) break;
        offset += data.length;
      }
    }

    await scan();
    let removed = 0;
    for (let index = 0; index < expired.length; index += 100) {
      const batch = expired.slice(index, index + 100);
      const { error } = await bucket.remove(batch);
      if (error) throw error;
      removed += batch.length;
    }

    const nowIso = new Date().toISOString();
    const proofTables = [
      "gti_missions_challenge_entries",
      "gti_missions_water_entries",
      "gti_missions_exercise_entries",
    ];
    let metadataCleared = 0;

    for (const table of proofTables) {
      const { data: rows, error: selectError } = await supabase
        .from(table)
        .select("id")
        .not("photo_path", "is", null)
        .lte("photo_expires_at", nowIso)
        .limit(1000);
      if (selectError) throw selectError;

      if (rows?.length) {
        const ids = rows.map((row: { id: string }) => row.id);
        const { error: updateError } = await supabase
          .from(table)
          .update({ photo_path: null, photo_expires_at: null })
          .in("id", ids);
        if (updateError) throw updateError;
        metadataCleared += rows.length;
      }
    }

    return new Response(
      JSON.stringify({ ok: true, removed, metadata_cleared: metadataCleared }),
      { status: 200, headers },
    );
  } catch (error) {
    console.error("cleanup-gti-missions-checkins", error);
    return new Response(JSON.stringify({ ok: false, error: "cleanup_failed" }), {
      status: 500,
      headers,
    });
  }
});