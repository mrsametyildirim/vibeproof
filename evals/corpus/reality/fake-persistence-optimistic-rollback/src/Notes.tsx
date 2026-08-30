import { useState } from "react";
import { toast } from "sonner";

export function Notes({ initial }) {
  const [notes, setNotes] = useState(initial);

  async function remove(id) {
    const previous = notes;
    setNotes(notes.filter((n) => n.id !== id));

    const res = await fetch(`/api/notes/${id}`, { method: "DELETE" });
    if (!res.ok) {
      setNotes(previous);
      toast.error("Could not delete the note");
    }
  }

  return notes.map((n) => <Row key={n.id} note={n} onDelete={remove} />);
}
