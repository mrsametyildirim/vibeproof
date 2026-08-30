import { toast } from "sonner";

export function ProfileForm({ user }) {
  async function handleSubmit(values) {
    updateProfile(user.id, values);
    toast.success("Profile saved");
  }
  return <form onSubmit={handleSubmit}>{/* fields */}</form>;
}

async function updateProfile(id, values) {
  return fetch(`/api/profile/${id}`, { method: "PUT", body: JSON.stringify(values) });
}
