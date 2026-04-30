"use client";

import { useEffect, useState } from "react";
import {
    listPlaygroundTemplatesAdmin,
    createPlaygroundTemplate,
    patchPlaygroundTemplate,
    deletePlaygroundTemplate,
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

const EMPTY_FORM = { slug: "", label: "", description: "", body: "" };

export default function AdminTemplatesPage() {
    const [rows, setRows] = useState(null);
    const [editing, setEditing] = useState(null); // null | "new" | row object
    const [form, setForm] = useState(EMPTY_FORM);
    const [saving, setSaving] = useState(false);

    useEffect(() => {
        load();
    }, []);

    async function load() {
        try {
            setRows(await listPlaygroundTemplatesAdmin());
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
            description: row.description ?? "",
            body: row.body,
        });
        setEditing(row);
    }

    function close() {
        setEditing(null);
        setForm(EMPTY_FORM);
    }

    async function softDelete(row) {
        if (!confirm(`Soft-delete template "${row.label}"? It will be hidden from the playground but retained for audit.`)) {
            return;
        }
        try {
            await deletePlaygroundTemplate(row.id);
            toast.success(`Archived ${row.slug}`);
            load();
        } catch (err) {
            toast.error(err.message);
        }
    }

    async function restore(row) {
        try {
            await patchPlaygroundTemplate(row.id, { is_active: true });
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
            if (!form.label.trim()) {
                toast.error("Label required");
                return;
            }
            if (!form.body.trim()) {
                toast.error("Body required");
                return;
            }
            setSaving(true);
            try {
                await createPlaygroundTemplate({
                    slug: form.slug,
                    label: form.label,
                    description: form.description || null,
                    body: form.body,
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
        // edit existing
        const payload = {};
        if (form.label !== editing.label) payload.label = form.label;
        if ((form.description ?? "") !== (editing.description ?? "")) {
            payload.description = form.description || null;
        }
        if (form.body !== editing.body) payload.body = form.body;
        if (Object.keys(payload).length === 0) {
            toast("No changes to save");
            close();
            return;
        }
        setSaving(true);
        try {
            await patchPlaygroundTemplate(editing.id, payload);
            toast.success(`Updated ${editing.slug}`);
            close();
            load();
        } catch (err) {
            toast.error(err.message);
        } finally {
            setSaving(false);
        }
    }

    return (
        <div className="space-y-4">
            <div className="flex items-center justify-between">
                <div>
                    <h1 className="text-2xl font-bold text-white">Templates</h1>
                    <p className="text-slate-400 mt-1 text-sm">
                        User-prompt templates with a {"{{MODEL}}"} placeholder. Active rows
                        appear in the playground dropdown.
                    </p>
                </div>
                <Button
                    size="sm"
                    onClick={openNew}
                    className="bg-indigo-600 hover:bg-indigo-700"
                >
                    <Plus className="w-3 h-3 mr-1" /> New template
                </Button>
            </div>

            {rows === null ? (
                <Card className="bg-slate-900 border-slate-800 p-4 space-y-2">
                    {[1, 2, 3].map((i) => (
                        <Skeleton key={i} className="h-16 w-full bg-slate-800" />
                    ))}
                </Card>
            ) : rows.length === 0 ? (
                <Card className="bg-slate-900 border-slate-800 p-6">
                    <p className="text-sm text-slate-500 italic">No templates yet.</p>
                </Card>
            ) : (
                <Card className="bg-slate-900 border-slate-800 p-4">
                    <ul className="divide-y divide-slate-800">
                        {rows.map((row) => (
                            <li key={row.id} className="py-3 first:pt-0 last:pb-0 flex gap-3">
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
                                    {row.description && (
                                        <p className="text-xs text-slate-400 truncate">
                                            {row.description}
                                        </p>
                                    )}
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
                </Card>
            )}

            <Dialog open={editing !== null} onOpenChange={(open) => !open && close()}>
                <DialogContent className="bg-slate-900 border-slate-800 max-w-2xl">
                    <DialogHeader>
                        <DialogTitle className="text-slate-100">
                            {editing === "new" ? "New template" : `Edit ${editing?.slug ?? ""}`}
                        </DialogTitle>
                        <DialogDescription className="text-slate-500 text-xs">
                            Body must contain the literal {"{{MODEL}}"} placeholder.
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
                            <Label className="text-xs text-slate-400">Description</Label>
                            <Input
                                value={form.description}
                                onChange={(e) =>
                                    setForm((f) => ({ ...f, description: e.target.value }))
                                }
                                placeholder="Optional one-line summary"
                                className="bg-slate-800 border-slate-700 text-slate-100"
                            />
                        </div>
                        <div className="space-y-1">
                            <Label className="text-xs text-slate-400">Body</Label>
                            <Textarea
                                value={form.body}
                                onChange={(e) =>
                                    setForm((f) => ({ ...f, body: e.target.value }))
                                }
                                rows={10}
                                spellCheck={false}
                                className="bg-slate-800 border-slate-700 text-slate-100 font-mono text-xs"
                            />
                            {!form.body.includes("{{MODEL}}") && form.body.length > 0 && (
                                <p className="text-[11px] text-amber-400">
                                    Warning: body has no {"{{MODEL}}"} placeholder; the
                                    persona description will not be inserted.
                                </p>
                            )}
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
