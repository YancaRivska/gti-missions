insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('gti-missions-web','gti-missions-web',true,1048576,array['text/html','text/css','application/javascript','image/svg+xml','application/json','application/manifest+json'])
on conflict (id) do update set public=true,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;
