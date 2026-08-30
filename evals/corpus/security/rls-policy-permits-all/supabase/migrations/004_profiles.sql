create table profiles (
  id uuid primary key,
  user_id uuid references auth.users,
  email text,
  phone text
);

alter table profiles enable row level security;

create policy "public read" on profiles
  for select using (true);
