"use client";

import { useEffect, useState } from "react";
import {
    fetchTryOnSystemPrompt,
    patchTryOnSystemPrompt,
} from "@/lib/api";
import { Card } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { Skeleton } from "@/components/ui/skeleton";
import { Save, RotateCcw, Loader2 } from "lucide-react";
import { toast } from "sonner";

export default function AdminSystemPromptPage() {
    const [original, setOriginal] = useState(null);
    const [label, setLabel] = useState("");
    const [content, setContent] = useState("");
    const [saving, setSaving] = useState(false);

    useEffect(() => {
        fetchTryOnSystemPrompt()
            .then((sp) => {
                setOriginal(sp);
                setLabel(sp.label);
                setContent(sp.content);
            })
            .catch((err) => toast.error(err.message));
    }, []);

    const dirty =
        original !== null &&
        (label !== original.label || content !== original.content);

    function discard() {
        if (!original) return;
        setLabel(original.label);
        setContent(original.content);
    }

    async function save() {
        setSaving(true);
        try {
            const payload = {};
            if (label !== original.label) payload.label = label;
            if (content !== original.content) payload.content = content;
            const updated = await patchTryOnSystemPrompt(payload);
            setOriginal(updated);
            setLabel(updated.label);
            setContent(updated.content);
            toast.success("System prompt updated");
        } catch (err) {
            toast.error(err.message);
        } finally {
            setSaving(false);
        }
    }

    if (!original) {
        return (
            <Card className="bg-slate-900 border-slate-800 p-4 space-y-3">
                <Skeleton className="h-6 w-48 bg-slate-800" />
                <Skeleton className="h-9 w-full bg-slate-800" />
                <Skeleton className="h-64 w-full bg-slate-800" />
            </Card>
        );
    }

    return (
        <div className="space-y-4">
            <div>
                <h1 className="text-2xl font-bold text-white">System prompt</h1>
                <p className="text-slate-400 mt-1 text-sm">
                    The active singleton sent on every try-on generation. Slug
                    is immutable; edits to label and content take effect immediately.
                </p>
            </div>

            <Card className="bg-slate-900 border-slate-800 p-4 space-y-4">
                <div className="space-y-1">
                    <Label className="text-xs text-slate-400">Slug</Label>
                    <Input
                        value={original.slug}
                        readOnly
                        className="bg-slate-800 border-slate-700 text-slate-400"
                    />
                </div>

                <div className="space-y-1">
                    <Label className="text-xs text-slate-400">Label</Label>
                    <Input
                        value={label}
                        onChange={(e) => setLabel(e.target.value)}
                        className="bg-slate-800 border-slate-700 text-slate-100"
                    />
                </div>

                <div className="space-y-1">
                    <div className="flex items-center justify-between">
                        <Label className="text-xs text-slate-400">Content</Label>
                        <span className="text-xs text-slate-500">
                            {content.length} / 32000
                        </span>
                    </div>
                    <Textarea
                        value={content}
                        onChange={(e) => setContent(e.target.value)}
                        rows={20}
                        spellCheck={false}
                        className="bg-slate-800 border-slate-700 text-slate-100 font-mono text-xs resize-y"
                    />
                </div>

                <div className="flex items-center justify-end gap-2">
                    <Button
                        variant="outline"
                        size="sm"
                        onClick={discard}
                        disabled={!dirty || saving}
                        className="border-slate-700 text-slate-300 hover:bg-slate-800"
                    >
                        <RotateCcw className="w-3 h-3 mr-1" /> Discard
                    </Button>
                    <Button
                        size="sm"
                        onClick={save}
                        disabled={!dirty || saving}
                        className="bg-indigo-600 hover:bg-indigo-700"
                    >
                        {saving ? (
                            <><Loader2 className="w-3 h-3 mr-1 animate-spin" /> Saving…</>
                        ) : (
                            <><Save className="w-3 h-3 mr-1" /> Save</>
                        )}
                    </Button>
                </div>
            </Card>
        </div>
    );
}
