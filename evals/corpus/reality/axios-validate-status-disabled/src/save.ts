import { api } from "./client";
import { toast } from "sonner";

export async function saveSettings(values: Settings) {
  await api.post("/settings", values);
  toast.success("Settings saved");
}
