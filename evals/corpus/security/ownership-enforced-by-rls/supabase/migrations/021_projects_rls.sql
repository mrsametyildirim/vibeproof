alter table projects enable row level security;

create policy "owners delete their projects"
  on projects for delete
  using (auth.uid() = user_id);
