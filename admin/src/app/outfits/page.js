"use client";

import { useState, useEffect } from "react";
import { suggestOutfits, listOutfits, saveOutfit, deleteOutfit } from "@/lib/api";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Textarea } from "@/components/ui/textarea";
import {
    Table, TableBody, TableCell, TableHead, TableHeader, TableRow,
} from "@/components/ui/table";
import {
    Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle,
} from "@/components/ui/dialog";
import { Skeleton } from "@/components/ui/skeleton";
import { Loader2, Sparkles, Trash2 } from "lucide-react";
import { toast } from "sonner";
import JsonViewer from "@/components/JsonViewer";

export default function OutfitsPage() {
    // Suggest state
    const [suggestForm, setSuggestForm] = useState({ occasion: "", season: "", color_preference: "", source: "mix" });
    const [suggestions, setSuggestions] = useState(null);
    const [suggestLoading, setSuggestLoading] = useState(false);

    // Saved outfits state
    const [outfits, setOutfits] = useState(null);
    const [outfitsLoading, setOutfitsLoading] = useState(false);
    const [deleteTarget, setDeleteTarget] = useState(null);
    const [deleteLoading, setDeleteLoading] = useState(false);

    // Create state
    const [createForm, setCreateForm] = useState({ source: "playground", slots: "{}", generated_image_url: "" });
    const [createLoading, setCreateLoading] = useState(false);

    async function loadOutfits() {
        setOutfitsLoading(true);
        try {
            const data = await listOutfits();
            setOutfits(data.items);
        } catch (err) {
            toast.error(err.message);
        } finally {
            setOutfitsLoading(false);
        }
    }

    useEffect(() => { loadOutfits(); }, []);

    async function handleSuggest(e) {
        e.preventDefault();
        setSuggestLoading(true);
        setSuggestions(null);
        try {
            const payload = {
                source: suggestForm.source,
                ...(suggestForm.occasion && { occasion: suggestForm.occasion }),
                ...(suggestForm.season && { season: suggestForm.season }),
                ...(suggestForm.color_preference && { color_preference: suggestForm.color_preference }),
            };
            const data = await suggestOutfits(payload);
            setSuggestions(data.outfits);
        } catch (err) {
            toast.error(err.message);
        } finally {
            setSuggestLoading(false);
        }
    }

    async function handleDelete() {
        if (!deleteTarget) return;
        setDeleteLoading(true);
        try {
            await deleteOutfit(deleteTarget.id);
            toast.success("Outfit deleted");
            setDeleteTarget(null);
            await loadOutfits();
        } catch (err) {
            toast.error(err.message);
        } finally {
            setDeleteLoading(false);
        }
    }

    async function handleCreate(e) {
        e.preventDefault();
        setCreateLoading(true);
        try {
            let slots;
            try { slots = JSON.parse(createForm.slots); } catch { toast.error("Invalid JSON in slots"); setCreateLoading(false); return; }
            await saveOutfit({
                source: createForm.source,
                slots,
                ...(createForm.generated_image_url && { generated_image_url: createForm.generated_image_url }),
            });
            toast.success("Outfit saved");
            setCreateForm({ source: "playground", slots: "{}", generated_image_url: "" });
            await loadOutfits();
        } catch (err) {
            toast.error(err.message);
        } finally {
            setCreateLoading(false);
        }
    }

    return (
        <div className="space-y-6">
            <div>
                <h1 className="text-2xl font-bold text-white">Outfits</h1>
                <p className="text-slate-400 mt-1">Generate AI outfit suggestions, view and manage saved outfits</p>
            </div>

            <Tabs defaultValue="suggest">
                <TabsList className="bg-slate-800 border-slate-700">
                    <TabsTrigger value="suggest" className="data-[state=active]:bg-indigo-600 data-[state=active]:text-white">AI Suggest</TabsTrigger>
                    <TabsTrigger value="saved" className="data-[state=active]:bg-indigo-600 data-[state=active]:text-white">Saved ({outfits?.length ?? "…"})</TabsTrigger>
                    <TabsTrigger value="create" className="data-[state=active]:bg-indigo-600 data-[state=active]:text-white">Create</TabsTrigger>
                </TabsList>

                {/* Suggest tab */}
                <TabsContent value="suggest" className="mt-4 space-y-4">
                    <Card className="bg-slate-900 border-slate-800">
                        <CardHeader>
                            <CardTitle className="text-white text-base flex items-center gap-2">
                                <Sparkles className="w-4 h-4 text-indigo-400" />
                                Generate Outfit Suggestions
                            </CardTitle>
                        </CardHeader>
                        <CardContent>
                            <form onSubmit={handleSuggest} className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
                                <div className="space-y-1">
                                    <Label className="text-xs text-slate-400">Occasion</Label>
                                    <Input placeholder="e.g. casual, formal" value={suggestForm.occasion}
                                        onChange={(e) => setSuggestForm({ ...suggestForm, occasion: e.target.value })}
                                        className="bg-slate-800 border-slate-700 text-slate-100 placeholder:text-slate-500 text-sm" />
                                </div>
                                <div className="space-y-1">
                                    <Label className="text-xs text-slate-400">Season</Label>
                                    <Input placeholder="e.g. summer, winter" value={suggestForm.season}
                                        onChange={(e) => setSuggestForm({ ...suggestForm, season: e.target.value })}
                                        className="bg-slate-800 border-slate-700 text-slate-100 placeholder:text-slate-500 text-sm" />
                                </div>
                                <div className="space-y-1">
                                    <Label className="text-xs text-slate-400">Color Preference</Label>
                                    <Input placeholder="e.g. neutral, bold" value={suggestForm.color_preference}
                                        onChange={(e) => setSuggestForm({ ...suggestForm, color_preference: e.target.value })}
                                        className="bg-slate-800 border-slate-700 text-slate-100 placeholder:text-slate-500 text-sm" />
                                </div>
                                <div className="space-y-1">
                                    <Label className="text-xs text-slate-400">Source</Label>
                                    <div className="flex gap-2">
                                        <select value={suggestForm.source}
                                            onChange={(e) => setSuggestForm({ ...suggestForm, source: e.target.value })}
                                            className="flex-1 h-10 px-3 text-sm rounded-md bg-slate-800 border border-slate-700 text-slate-100">
                                            <option value="mix">Mix</option>
                                            <option value="catalog">Catalog</option>
                                            <option value="wardrobe">Wardrobe</option>
                                        </select>
                                        <Button type="submit" disabled={suggestLoading} className="bg-indigo-600 hover:bg-indigo-700 shrink-0">
                                            {suggestLoading ? <Loader2 className="w-4 h-4 animate-spin" /> : <Sparkles className="w-4 h-4" />}
                                        </Button>
                                    </div>
                                </div>
                            </form>
                        </CardContent>
                    </Card>

                    {suggestLoading && (
                        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                            {Array.from({ length: 3 }).map((_, i) => <Skeleton key={i} className="h-40 w-full bg-slate-800 rounded-lg" />)}
                        </div>
                    )}

                    {suggestions && (
                        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                            {suggestions.map((outfit, i) => (
                                <Card key={i} className="bg-slate-900 border-slate-800">
                                    <CardHeader className="pb-2">
                                        <div className="flex items-center justify-between">
                                            <CardTitle className="text-sm text-white">Outfit {i + 1}</CardTitle>
                                            <Badge variant="outline" className="border-indigo-700 text-indigo-300 text-xs">AI Generated</Badge>
                                        </div>
                                        <p className="text-xs text-slate-400 italic">{outfit.style_note}</p>
                                    </CardHeader>
                                    <CardContent>
                                        <JsonViewer data={outfit.slots} maxHeight={150} />
                                    </CardContent>
                                </Card>
                            ))}
                        </div>
                    )}
                </TabsContent>

                {/* Saved tab */}
                <TabsContent value="saved" className="mt-4">
                    {outfitsLoading ? (
                        <div className="space-y-2">
                            {Array.from({ length: 4 }).map((_, i) => <Skeleton key={i} className="h-14 w-full bg-slate-800 rounded-md" />)}
                        </div>
                    ) : (
                        <div className="rounded-md border border-slate-800 overflow-hidden">
                            <Table>
                                <TableHeader>
                                    <TableRow className="border-slate-800 hover:bg-transparent">
                                        <TableHead className="text-slate-400">Source</TableHead>
                                        <TableHead className="text-slate-400">Slots</TableHead>
                                        <TableHead className="text-slate-400">Image</TableHead>
                                        <TableHead className="text-slate-400">Created</TableHead>
                                        <TableHead className="text-slate-400 text-right">ID</TableHead>
                                        <TableHead className="w-12"></TableHead>
                                    </TableRow>
                                </TableHeader>
                                <TableBody>
                                    {outfits?.length === 0 ? (
                                        <TableRow>
                                            <TableCell colSpan={6} className="text-center text-slate-500 py-8">No saved outfits</TableCell>
                                        </TableRow>
                                    ) : outfits?.map((outfit) => (
                                        <TableRow key={outfit.id} className="border-slate-800 hover:bg-slate-800/50">
                                            <TableCell>
                                                <Badge variant={outfit.source === "assistant" ? "default" : "secondary"}
                                                    className={outfit.source === "assistant" ? "bg-indigo-700" : "bg-slate-700 text-slate-300"}>
                                                    {outfit.source}
                                                </Badge>
                                            </TableCell>
                                            <TableCell className="max-w-xs">
                                                <JsonViewer data={outfit.slots} maxHeight={80} />
                                            </TableCell>
                                            <TableCell>
                                                {outfit.generated_image_url ? (
                                                    <img src={outfit.generated_image_url} alt="outfit" className="w-10 h-10 object-cover rounded border border-slate-700" />
                                                ) : <span className="text-slate-600 text-xs">none</span>}
                                            </TableCell>
                                            <TableCell className="text-slate-500 text-xs">{new Date(outfit.created_at).toLocaleDateString()}</TableCell>
                                            <TableCell className="text-right">
                                                <span className="text-[10px] font-mono text-slate-500 select-all">{outfit.id}</span>
                                            </TableCell>
                                            <TableCell>
                                                <Button variant="ghost" size="sm" onClick={() => setDeleteTarget(outfit)}
                                                    className="text-red-400 hover:text-red-300 hover:bg-red-950 h-7 w-7 p-0">
                                                    <Trash2 className="w-3.5 h-3.5" />
                                                </Button>
                                            </TableCell>
                                        </TableRow>
                                    ))}
                                </TableBody>
                            </Table>
                        </div>
                    )}
                </TabsContent>

                {/* Create tab */}
                <TabsContent value="create" className="mt-4">
                    <Card className="bg-slate-900 border-slate-800">
                        <CardHeader>
                            <CardTitle className="text-white text-base">Save New Outfit</CardTitle>
                        </CardHeader>
                        <CardContent>
                            <form onSubmit={handleCreate} className="space-y-4">
                                <div className="space-y-1">
                                    <Label className="text-xs text-slate-400">Source</Label>
                                    <select value={createForm.source} onChange={(e) => setCreateForm({ ...createForm, source: e.target.value })}
                                        className="w-full h-10 px-3 text-sm rounded-md bg-slate-800 border border-slate-700 text-slate-100">
                                        <option value="playground">Playground</option>
                                        <option value="assistant">Assistant</option>
                                    </select>
                                </div>
                                <div className="space-y-1">
                                    <Label className="text-xs text-slate-400">Slots (JSON)</Label>
                                    <Textarea value={createForm.slots}
                                        onChange={(e) => setCreateForm({ ...createForm, slots: e.target.value })}
                                        rows={6} placeholder='{"top": {"id": "...", "name": "...", "image_url": "..."}}'
                                        className="bg-slate-800 border-slate-700 text-slate-100 placeholder:text-slate-500 text-sm font-mono resize-none" />
                                </div>
                                <div className="space-y-1">
                                    <Label className="text-xs text-slate-400">Generated Image URL (optional)</Label>
                                    <Input placeholder="https://..." value={createForm.generated_image_url}
                                        onChange={(e) => setCreateForm({ ...createForm, generated_image_url: e.target.value })}
                                        className="bg-slate-800 border-slate-700 text-slate-100 placeholder:text-slate-500 text-sm" />
                                </div>
                                <Button type="submit" disabled={createLoading} className="bg-indigo-600 hover:bg-indigo-700">
                                    {createLoading ? <><Loader2 className="w-4 h-4 animate-spin mr-2" />Saving...</> : "Save Outfit"}
                                </Button>
                            </form>
                        </CardContent>
                    </Card>
                </TabsContent>
            </Tabs>

            <Dialog open={!!deleteTarget} onOpenChange={(open) => !open && setDeleteTarget(null)}>
                <DialogContent className="bg-slate-900 border-slate-700 text-slate-100">
                    <DialogHeader>
                        <DialogTitle>Delete Outfit</DialogTitle>
                        <DialogDescription className="text-slate-400">
                            This will permanently delete the outfit. Are you sure?
                            {deleteTarget && <span className="block mt-1 text-xs font-mono text-slate-500">{deleteTarget.id}</span>}
                        </DialogDescription>
                    </DialogHeader>
                    <DialogFooter>
                        <Button variant="outline" onClick={() => setDeleteTarget(null)} className="border-slate-600 text-slate-300 hover:bg-slate-800">Cancel</Button>
                        <Button variant="destructive" onClick={handleDelete} disabled={deleteLoading}>
                            {deleteLoading ? <Loader2 className="w-4 h-4 animate-spin mr-2" /> : null}Delete
                        </Button>
                    </DialogFooter>
                </DialogContent>
            </Dialog>
        </div>
    );
}
