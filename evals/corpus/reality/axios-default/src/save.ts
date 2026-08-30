import axios from "axios";
import { toast } from "sonner";

export async function saveSettings(values: Settings) {
  await axios.post("/api/settings", values);
  toast.success("Settings saved");
}
