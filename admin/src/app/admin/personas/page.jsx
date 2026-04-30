"use client";

import { useEffect, useState } from "react";
import {
    listTryOnPersonasAdmin,
    createTryOnPersona,
    patchTryOnPersona,
    deleteTryOnPersona,
} from "@/lib/api";
import { Card } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { Badge } from "@/components/ui/badge";
import { Skeleton } from "@/components/ui/skeleton";
import {
    Dialog,
    DialogContent,
    DialogHeader,
    DialogTitle,
    DialogDescription,
} from "@/components/ui/dialog";
import { Plus, Pencil, Archive, RotateCcw, Save, Loader2 } from "lucide-react";
import { toast } from "sonner";

const SLUG_RE = /^[a-z0-9_]+$/;

const EMPTY_FORM = {
    slug: "",
    label: "",
    gender: "female",
    description: "",
};

export default function AdminPersonasPage() {
    const [rows, setRows] = useState(null);
    const [editing, setEditing] = useState(null);
    const [form, setForm] = useState(EMPTY_FORM);
    const [saving, setSaving] = useState(false);

    useEffect(() => {
        load();
    }, []);

    async function load() {
        try {
            setRows(await listTryOnPersonasAdmin());
        } catch (err) {
            toast.error(err.message);
            setRows([]);
        }
    }

    function openNew() {
        setForm(EMPTY_FORM);
        setEditing("new");
    }

    function openEdit(row) {
        setForm({
            slug: row.slug,
            label: row.label,
            gender: row.gender,
            description: row.description,
        });
        setEditing(row);
    }

    function close() {
        setEditing(null);
        setForm(EMPTY_FORM);
    }

    async function softDelete(row) {
        if (!confirm(`Soft-delete persona "${row.label}"?`)) return;
        try {
            await deleteTryOnPersona(row.id);
            toast.success(`Archived ${row.slug}`);
            load();
        } catch (err) {
            toast.error(err.message);
        }
    }

    async function restore(row) {
        try {
            await patchTryOnPersona(row.id, { is_active: true });
            toast.success(`Restored ${row.slug}`);
            load();
        } catch (err) {
            toast.error(err.message);
        }
    }

    async function submit() {
        if (editing === "new") {
            if (!SLUG_RE.test(form.slug)) {
                toast.error("Slug must be lowercase letters, digits, or underscores");
                return;
            }
            if (!form.label.trim() || !form.description.trim()) {
                toast.error("Label and description required");
                return;
            }
            setSaving(true);
            try {
                await createTryOnPersona({
                    slug: form.slug,
                    label: form.label,
                    gender: form.gender,
                    description: form.description,
                });
                toast.success(`Created ${form.slug}`);
                close();
                load();
            } catch (err) {
                toast.error(err.message);
            } finally {
                setSaving(false);
            }
            return;
        }
        const payload = {};
        if (form.label !== editing.label) payload.label = form.label;
        if (form.description !== editing.description) {
            payload.description = form.description;
        }
        if (Object.keys(payload).length === 0) {
            toast("No changes to save");
            close();
            return;
        }
        setSaving(true);
        try {
            await patchTryOnPersona(editing.id, payload);
            toast.success(`Updated ${editing.slug}`);
            close();
            load();
        } catch (err) {
            toast.error(err.message);
        } finally {
            setSaving(false);
        }
    }

    const grouped = rows
        ? {
              female: rows.filter((p) => p.gender === "female"),
              male: rows.filter((p) => p.gender === "male"),
          }
        : null;

    return (
        <div className="space-y-4">
            <div className="flex items-center justify-between">
                <div>
                    <h1 className="text-2xl font-bold text-white">Personas</h1>
                    <p className="text-slate-400 mt-1 text-sm">
                        Model personas slotted into a template body via the {"{{MODEL}}"}
                        placeholder. Gender is fixed at create time.
                    </p>
                </div>
                <Button
                    size="sm"
                    onClick={openNew}
                    className="bg-indigo-600 hover:bg-indigo-700"
                >
                    <Plus className="w-3 h-3 mr-1" /> New persona
                </Button>
            </div>

            {!grouped ? (
                <Card className="bg-slate-900 border-slate-800 p-4 space-y-2">
                    {[1, 2, 3].map((i) => (
                        <Skeleton key={i} className="h-16 w-full bg-slate-800" />
                    ))}
                </Card>
            ) : (
                ["female", "male"].map((gender) => (
                    <Card
                        key={gender}
                        className="bg-slate-900 border-slate-800 p-4 space-y-2"
                    >
                        <h2 className="text-sm font-medium text-slate-300 capitalize">
                            {gender} ({grouped[gender].length})
                        </h2>
                        {grouped[gender].length === 0 ? (
                            <p className="text-xs text-slate-500 italic">None.</p>
                        ) : (
                            <ul className="divide-y divide-slate-800">
                                {grouped[gender].map((row) => (
                                    <li
                                        key={row.id}
                                        className="py-3 flex gap-3 first:pt-0 last:pb-0"
                                    >
                                        <div className="flex-1 min-w-0 space-y-1">
                                            <div className="flex items-center gap-2">
                                                <span className="text-sm font-medium text-slate-100">
                                                    {row.label}
                                                </span>
                                                <Badge
                                                    variant="outline"
                                                    className={
                                                        row.is_active
                                                            ? "border-emerald-800 text-emerald-400 text-[10px]"
                                                            : "border-slate-700 text-slate-500 text-[10px]"
                                                    }
                                                >
                                                    {row.is_active ? "active" : "archived"}
                                                </Badge>
                                                <span className="text-xs text-slate-500 font-mono">
                                                    {row.slug}
                                                </span>
                                            </div>
                                            <p className="text-xs text-slate-400 line-clamp-2 whitespace-pre-line">
                                                {row.description}
                                            </p>
                                        </div>
                                        <div className="shrink-0 flex items-center gap-1">
                                            <Button
                                                size="sm"
                                                variant="outline"
                                                onClick={() => openEdit(row)}
                                                className="border-slate-700 text-slate-300 hover:bg-slate-800 h-7 text-xs"
                                            >
                                                <Pencil className="w-3 h-3 mr-1" /> Edit
                                            </Button>
                                            {row.is_active ? (
                                                <Button
                                                    size="sm"
                                                    variant="outline"
                                                    onClick={() => softDelete(row)}
                                                    className="border-slate-700 text-slate-300 hover:bg-slate-800 h-7 text-xs"
                                                >
                                                    <Archive className="w-3 h-3 mr-1" /> Archive
                                                </Button>
                                            ) : (
                                                <Button
                                                    size="sm"
                                                    variant="outline"
                                                    onClick={() => restore(row)}
                                                    className="border-slate-700 text-slate-300 hover:bg-slate-800 h-7 text-xs"
                                                >
                                                    <RotateCcw className="w-3 h-3 mr-1" /> Restore
                                                </Button>
                                            )}
                                        </div>
                                    </li>
                                ))}
                            </ul>
                        )}
                    </Card>
                ))
            )}

            <Dialog open={editing !== null} onOpenChange={(open) => !open && close()}>
                <DialogContent className="bg-slate-900 border-slate-800 max-w-xl">
                    <DialogHeader>
                        <DialogTitle className="text-slate-100">
                            {editing === "new" ? "New persona" : `Edit ${editing?.slug ?? ""}`}
                        </DialogTitle>
                        <DialogDescription className="text-slate-500 text-xs">
                            Persona descriptions appear inside templates wherever
                            {" {{MODEL}}"} is written. Gender is immutable after create.
                        </DialogDescription>
                    </DialogHeader>
                    <div className="space-y-3">
                        <div className="space-y-1">
                            <Label className="text-xs text-slate-400">Slug</Label>
                            <Input
                                value={form.slug}
                                onChange={(e) =>
                                    setForm((f) => ({ ...f, slug: e.target.value }))
                                }
                                disabled={editing !== "new"}
                                placeholder="lowercase_with_underscores"
                                className="bg-slate-800 border-slate-700 text-slate-100"
                            />
                        </div>
                        <div className="grid grid-cols-2 gap-3">
                            <div className="space-y-1">
                                <Label className="text-xs text-slate-400">Label</Label>
                                <Input
                                    value={form.label}
                                    onChange={(e) =>
                                        setForm((f) => ({ ...f, label: e.target.value }))
                                    }
                                    className="bg-slate-800 border-slate-700 text-slate-100"
                                />
                            </div>
                            <div className="space-y-1">
                                <Label className="text-xs text-slate-400">Gender</Label>
                                <select
                                    value={form.gender}
                                    onChange={(e) =>
                                        setForm((f) => ({ ...f, gender: e.target.value }))
                                    }
                                    disabled={editing !== "new"}
                                    className="w-full h-9 px-2 text-sm rounded-md bg-slate-800 border border-slate-700 text-slate-100 disabled:opacity-60"
                                >
                                    <option value="female">Female</option>
                                    <option value="male">Male</option>
                                </select>
                            </div>
                        </div>
                        <div className="space-y-1">
                            <Label className="text-xs text-slate-400">Description</Label>
                            <Textarea
                                value={form.description}
                                onChange={(e) =>
                                    setForm((f) => ({ ...f, description: e.target.value }))
                                }
                                rows={8}
                                spellCheck={false}
                                placeholder={"- Mid-20s\n- Tan skin tone\n- Slim build\n- ..."}
                                className="bg-slate-800 border-slate-700 text-slate-100 font-mono text-xs"
                            />
                        </div>
                        <div className="flex justify-end gap-2 pt-2">
                            <Button
                                size="sm"
                                variant="outline"
                                onClick={close}
                                disabled={saving}
                                className="border-slate-700 text-slate-300 hover:bg-slate-800"
                            >
                                Cancel
                            </Button>
                            <Button
                                size="sm"
                                onClick={submit}
                                disabled={saving}
                                className="bg-indigo-600 hover:bg-indigo-700"
                            >
                                {saving ? (
                                    <><Loader2 className="w-3 h-3 mr-1 animate-spin" /> Saving…</>
                                ) : (
                                    <><Save className="w-3 h-3 mr-1" /> {editing === "new" ? "Create" : "Save"}</>
                                )}
                            </Button>
                        </div>
                    </div>
                </DialogContent>
            </Dialog>
        </div>
    );
}
