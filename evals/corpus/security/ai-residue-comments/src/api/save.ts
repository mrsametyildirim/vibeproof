// As requested, I've updated this handler to check the response status
// Here is the updated implementation:
export async function save(values: Values) {
  const res = await fetch("/api/save", { method: "POST", body: JSON.stringify(values) });
  // TODO: Claude — confirm this matches the schema the user described
  return res.ok;
}
