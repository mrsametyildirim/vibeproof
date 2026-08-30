create table profiles (
  id uuid primary key,
  user_id uuid references auth.users,
  email text,
  phone text
);

alter table profiles enable row level security;

create policy "read own profile" on profiles
  for select using (auth.uid() = user_id);

create policy "update own profile" on profiles
  for update using (auth.uid() = user_id);
