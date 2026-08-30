import { useState } from "react";
import { toast } from "sonner";

export function Notes({ initial }) {
  const [notes, setNotes] = useState(initial);

  function remove(id) {
    setNotes(notes.filter((n) => n.id !== id));
    toast.success("Note deleted");
  }

  return notes.map((n) => <Row key={n.id} note={n} onDelete={remove} />);
}
