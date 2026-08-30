import { toast } from "sonner";

export function ProfileForm({ user }) {
  async function handleSubmit(values) {
    const res = await updateProfile(user.id, values);
    if (!res.ok) {
      toast.error("Could not save profile");
      return;
    }
    toast.success("Profile saved");
  }
  return <form onSubmit={handleSubmit}>{/* fields */}</form>;
}

async function updateProfile(id, values) {
  return fetch(`/api/profile/${id}`, { method: "PUT", body: JSON.stringify(values) });
}
