"use client";

import { useState, useEffect } from "react";
import { listWardrobe, tagWardrobeItem, createWardrobeItem, deleteWardrobeItem } from "@/lib/api";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import {
    Table, TableBody, TableCell, TableHead, TableHeader, TableRow,
} from "@/components/ui/table";
import {
    Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle,
} from "@/components/ui/dialog";
import { Skeleton } from "@/components/ui/skeleton";
import { Loader2, Upload, Trash2, ChevronLeft, ChevronRight, Image } from "lucide-react";
import { toast } from "sonner";

const LIMIT = 20;

export default function WardrobePage() {
    // Browse tab state
    const [items, setItems] = useState(null);
    const [totalItems, setTotalItems] = useState(0);
    const [offset, setOffset] = useState(0);
    const [slotFilter, setSlotFilter] = useState("");
    const [categoryFilter, setCategoryFilter] = useState("");
    const [sortFilter, setSortFilter] = useState("recent");
    const [browseLoading, setBrowseLoading] = useState(false);
    const [deleteTarget, setDeleteTarget] = useState(null);
    const [deleteLoading, setDeleteLoading] = useState(false);

    // AI Tag tab state
    const [tagFile, setTagFile] = useState(null);
    const [tagResult, setTagResult] = useState(null);
    const [tagLoading, setTagLoading] = useState(false);

    // Create tab state
    const [createForm, setCreateForm] = useState({ slot: "", image_url: "" });
    const [createLoading, setCreateLoading] = useState(false);

    async function loadWardrobe(newOffset = 0) {
        setBrowseLoading(true);
        try {
            const data = await listWardrobe({
                slot: slotFilter || undefined,
                category: categoryFilter || undefined,
                sort: sortFilter,
                limit: LIMIT,
                offset: newOffset,
            });
            setItems(data.items);
            setTotalItems(data.total);
            setOffset(newOffset);
        } catch (err) {
            toast.error(err.message);
        } finally {
            setBrowseLoading(false);
        }
    }

    useEffect(() => { loadWardrobe(0); }, []);

    async function handleDelete() {
        if (!deleteTarget) return;
        setDeleteLoading(true);
        try {
            await deleteWardrobeItem(deleteTarget.id);
            toast.success("Item deleted");
            setDeleteTarget(null);
            await loadWardrobe(offset);
        } catch (err) {
            toast.error(err.message);
        } finally {
            setDeleteLoading(false);
        }
    }

    async function handleTag() {
        if (!tagFile) { toast.error("Select an image file"); return; }
        setTagLoading(true);
        setTagResult(null);
        try {
            const result = await tagWardrobeItem(tagFile);
            setTagResult(result);
        } catch (err) {
            toast.error(err.message);
        } finally {
            setTagLoading(false);
        }
    }

    async function handleCreate(e) {
        e.preventDefault();
        if (!createForm.slot || !createForm.image_url) {
            toast.error("Slot and image URL are required");
            return;
        }
        setCreateLoading(true);
        try {
            const colorVal = createForm.color ? createForm.color.split(",").map(c => c.trim()).filter(Boolean) : undefined;
            const tagsVal = createForm.style_tags ? createForm.style_tags.split(",").map(t => t.trim()).filter(Boolean) : undefined;
            const occasionVal = createForm.occasion_tags ? createForm.occasion_tags.split(",").map(t => t.trim()).filter(Boolean) : undefined;
            const patternVal = createForm.pattern ? createForm.pattern.split(",").map(p => p.trim()).filter(Boolean) : undefined;
            await createWardrobeItem({
                slot: createForm.slot,
                category: createForm.category || undefined,
                subcategory: createForm.subcategory || undefined,
                color: colorVal,
                pattern: patternVal,
                fit: createForm.fit || undefined,
                style_tags: tagsVal,
                occasion_tags: occasionVal,
                image_url: createForm.image_url,
            });
            toast.success("Wardrobe item created");
            setCreateForm({ slot: "", image_url: "" });
            await loadWardrobe(0);
        } catch (err) {
            toast.error(err.message);
        } finally {
            setCreateLoading(false);
        }
    }

    const totalPages = Math.ceil(totalItems / LIMIT);
    const currentPage = Math.floor(offset / LIMIT) + 1;

    return (
        <div className="space-y-6">
            <div>
                <h1 className="text-2xl font-bold text-white">Wardrobe</h1>
                <p className="text-slate-400 mt-1">Browse, tag, and manage wardrobe items</p>
            </div>

            <Tabs defaultValue="browse">
                <TabsList className="bg-slate-800 border-slate-700">
                    <TabsTrigger value="browse" className="data-[state=active]:bg-indigo-600 data-[state=active]:text-white">Browse</TabsTrigger>
                    <TabsTrigger value="tag" className="data-[state=active]:bg-indigo-600 data-[state=active]:text-white">AI Tag</TabsTrigger>
                    <TabsTrigger value="create" className="data-[state=active]:bg-indigo-600 data-[state=active]:text-white">Create</TabsTrigger>
                </TabsList>

                {/* Browse tab */}
                <TabsContent value="browse" className="mt-4 space-y-4">
                    <div className="flex flex-wrap gap-3">
                        <div className="flex items-center gap-2">
                            <Label className="text-xs text-slate-400 whitespace-nowrap">Slot</Label>
                            <Input
                                placeholder="e.g. top"
                                value={slotFilter}
                                onChange={(e) => setSlotFilter(e.target.value)}
                                className="bg-slate-800 border-slate-700 text-slate-100 placeholder:text-slate-500 h-8 text-sm w-32"
                            />
                        </div>
                        <div className="flex items-center gap-2">
                            <Label className="text-xs text-slate-400 whitespace-nowrap">Category</Label>
                            <Input
                                placeholder="e.g. blouse"
                                value={categoryFilter}
                                onChange={(e) => setCategoryFilter(e.target.value)}
                                className="bg-slate-800 border-slate-700 text-slate-100 placeholder:text-slate-500 h-8 text-sm w-32"
                            />
                        </div>
                        <div className="flex items-center gap-2">
                            <Label className="text-xs text-slate-400 whitespace-nowrap">Sort</Label>
                            <select
                                value={sortFilter}
                                onChange={(e) => setSortFilter(e.target.value)}
                                className="h-8 px-2 text-sm rounded-md bg-slate-800 border border-slate-700 text-slate-100"
                            >
                                <option value="recent">Recent</option>
                                <option value="color">Color</option>
                            </select>
                        </div>
                        <Button onClick={() => loadWardrobe(0)} size="sm" className="bg-indigo-600 hover:bg-indigo-700 h-8">
                            {browseLoading ? <Loader2 className="w-3 h-3 animate-spin" /> : "Filter"}
                        </Button>
                    </div>

                    {browseLoading ? (
                        <div className="space-y-2">
                            {Array.from({ length: 5 }).map((_, i) => <Skeleton key={i} className="h-14 w-full bg-slate-800 rounded-md" />)}
                        </div>
                    ) : (
                        <>
                            <div className="flex items-center justify-between text-sm text-slate-400">
                                <span>{totalItems} items</span>
                                {totalPages > 1 && (
                                    <div className="flex items-center gap-2">
                                        <Button variant="outline" size="sm" disabled={currentPage === 1}
                                            onClick={() => loadWardrobe(offset - LIMIT)}
                                            className="border-slate-700 text-slate-300 hover:bg-slate-800 h-7">
                                            <ChevronLeft className="w-3 h-3" />
                                        </Button>
                                        <span>Page {currentPage} / {totalPages}</span>
                                        <Button variant="outline" size="sm" disabled={currentPage === totalPages}
                                            onClick={() => loadWardrobe(offset + LIMIT)}
                                            className="border-slate-700 text-slate-300 hover:bg-slate-800 h-7">
                                            <ChevronRight className="w-3 h-3" />
                                        </Button>
                                    </div>
                                )}
                            </div>
                            <div className="rounded-md border border-slate-800 overflow-hidden">
                                <Table>
                                    <TableHeader>
                                        <TableRow className="border-slate-800 hover:bg-transparent">
                                            <TableHead className="text-slate-400 w-16">Image</TableHead>
                                            <TableHead className="text-slate-400">Slot / Category</TableHead>
                                            <TableHead className="text-slate-400">Color</TableHead>
                                            <TableHead className="text-slate-400">Pattern</TableHead>
                                            <TableHead className="text-slate-400">Fit</TableHead>
                                            <TableHead className="text-slate-400">Used</TableHead>
                                            <TableHead className="text-slate-400">Created</TableHead>
                                            <TableHead className="text-slate-400 w-16"></TableHead>
                                        </TableRow>
                                    </TableHeader>
                                    <TableBody>
                                        {items?.length === 0 ? (
                                            <TableRow>
                                                <TableCell colSpan={8} className="text-center text-slate-500 py-8">No wardrobe items</TableCell>
                                            </TableRow>
                                        ) : items?.map((item) => (
                                            <TableRow key={item.id} className="border-slate-800 hover:bg-slate-800/50">
                                                <TableCell>
                                                    {item.image_url ? (
                                                        <img src={item.image_url} alt={item.category || item.slot} className="w-10 h-10 object-cover rounded border border-slate-700" />
                                                    ) : (
                                                        <div className="w-10 h-10 bg-slate-800 rounded border border-slate-700 flex items-center justify-center">
                                                            <Image className="w-4 h-4 text-slate-600" />
                                                        </div>
                                                    )}
                                                </TableCell>
                                                <TableCell>
                                                    <div>
                                                        <Badge variant="outline" className="border-slate-600 text-slate-300 text-xs">{item.slot || "—"}</Badge>
                                                        {item.category && <p className="text-[11px] text-slate-300 mt-0.5">{item.category}</p>}
                                                        {item.subcategory && <p className="text-[10px] text-slate-500">{item.subcategory}</p>}
                                                    </div>
                                                </TableCell>
                                                <TableCell className="text-slate-300 text-xs">{item.color?.join(", ") || "—"}</TableCell>
                                                <TableCell className="text-slate-400 text-xs">{Array.isArray(item.pattern) ? item.pattern.join(", ") : (item.pattern || "—")}</TableCell>
                                                <TableCell className="text-slate-400 text-xs">{item.fit || "—"}</TableCell>
                                                <TableCell className="text-slate-400 text-xs">{item.times_used}</TableCell>
                                                <TableCell className="text-slate-500 text-xs">{new Date(item.created_at).toLocaleDateString()}</TableCell>
                                                <TableCell>
                                                    <Button
                                                        variant="ghost" size="sm"
                                                        onClick={() => setDeleteTarget(item)}
                                                        className="text-red-400 hover:text-red-300 hover:bg-red-950 h-7 w-7 p-0"
                                                    >
                                                        <Trash2 className="w-3.5 h-3.5" />
                                                    </Button>
                                                </TableCell>
                                            </TableRow>
                                        ))}
                                    </TableBody>
                                </Table>
                            </div>
                        </>
                    )}
                </TabsContent>

                {/* AI Tag tab */}
                <TabsContent value="tag" className="mt-4">
                    <Card className="bg-slate-900 border-slate-800">
                        <CardHeader>
                            <CardTitle className="text-white text-base">AI Image Tagging</CardTitle>
                            <p className="text-slate-400 text-sm">Upload a clothing image to auto-generate tags using Claude AI</p>
                        </CardHeader>
                        <CardContent className="space-y-4">
                            <div className="border-2 border-dashed border-slate-700 rounded-lg p-6 text-center">
                                <Upload className="w-8 h-8 text-slate-500 mx-auto mb-2" />
                                <p className="text-slate-400 text-sm mb-3">Select a JPEG or PNG (max 10 MB)</p>
                                <Input
                                    type="file"
                                    accept="image/jpeg,image/png"
                                    onChange={(e) => setTagFile(e.target.files[0] || null)}
                                    className="bg-slate-800 border-slate-700 text-slate-300 cursor-pointer"
                                />
                            </div>
                            {tagFile && (
                                <p className="text-xs text-slate-400">Selected: <span className="text-slate-200">{tagFile.name}</span> ({(tagFile.size / 1024).toFixed(1)} KB)</p>
                            )}
                            <Button onClick={handleTag} disabled={tagLoading || !tagFile} className="bg-indigo-600 hover:bg-indigo-700">
                                {tagLoading ? <><Loader2 className="w-4 h-4 animate-spin mr-2" />Tagging...</> : "Tag Image"}
                            </Button>

                            {tagResult && (
                                <div className="bg-slate-800 rounded-lg p-4 space-y-3 border border-slate-700">
                                    <div className="flex items-center justify-between">
                                        <h3 className="text-white font-medium text-sm">AI Tags</h3>
                                        <Badge className="bg-indigo-700">Confidence: {(tagResult.confidence * 100).toFixed(0)}%</Badge>
                                    </div>
                                    <div className="grid grid-cols-2 gap-2 text-sm">
                                        <div>
                                            <p className="text-slate-500 text-xs">Slot</p>
                                            <p className="text-slate-100">{tagResult.slot || "—"}</p>
                                        </div>
                                        <div>
                                            <p className="text-slate-500 text-xs">Category</p>
                                            <p className="text-slate-100">{tagResult.category || "—"}</p>
                                        </div>
                                        <div>
                                            <p className="text-slate-500 text-xs">Subcategory</p>
                                            <p className="text-slate-100">{tagResult.subcategory || "—"}</p>
                                        </div>
                                        <div>
                                            <p className="text-slate-500 text-xs">Fit</p>
                                            <p className="text-slate-100">{tagResult.fit || "—"}</p>
                                        </div>
                                    </div>
                                    <div>
                                        <p className="text-slate-500 text-xs mb-1">Colors</p>
                                        <div className="flex flex-wrap gap-1">
                                            {tagResult.color?.map((c) => <Badge key={c} variant="outline" className="border-slate-600 text-slate-300 text-xs">{c}</Badge>) || "—"}
                                        </div>
                                    </div>
                                    <div>
                                        <p className="text-slate-500 text-xs mb-1">Pattern</p>
                                        <div className="flex flex-wrap gap-1">
                                            {Array.isArray(tagResult.pattern)
                                                ? tagResult.pattern.map((p) => <Badge key={p} variant="outline" className="border-slate-600 text-slate-300 text-xs">{p}</Badge>)
                                                : (tagResult.pattern ? <Badge variant="outline" className="border-slate-600 text-slate-300 text-xs">{tagResult.pattern}</Badge> : "—")}
                                        </div>
                                    </div>
                                    <div>
                                        <p className="text-slate-500 text-xs mb-1">Style Tags</p>
                                        <div className="flex flex-wrap gap-1">
                                            {tagResult.style_tags?.map((t) => <Badge key={t} variant="secondary" className="bg-slate-700 text-slate-300 text-xs">{t}</Badge>) || "—"}
                                        </div>
                                    </div>
                                    <div>
                                        <p className="text-slate-500 text-xs mb-1">Occasion Tags</p>
                                        <div className="flex flex-wrap gap-1">
                                            {tagResult.occasion_tags?.map((o) => <Badge key={o} variant="secondary" className="bg-slate-700 text-slate-300 text-xs">{o}</Badge>) || "—"}
                                        </div>
                                    </div>
                                </div>
                            )}
                        </CardContent>
                    </Card>
                </TabsContent>

                {/* Create tab */}
                <TabsContent value="create" className="mt-4">
                    <Card className="bg-slate-900 border-slate-800">
                        <CardHeader>
                            <CardTitle className="text-white text-base">Create Wardrobe Item</CardTitle>
                        </CardHeader>
                        <CardContent>
                            <form onSubmit={handleCreate} className="grid grid-cols-1 md:grid-cols-2 gap-4">
                                {[
                                    { key: "slot", label: "Slot *", placeholder: "e.g. top" },
                                    { key: "category", label: "Category", placeholder: "e.g. blouse" },
                                    { key: "subcategory", label: "Subcategory", placeholder: "e.g. button-up" },
                                    { key: "color", label: "Colors (comma-separated)", placeholder: "e.g. black, white" },
                                    { key: "pattern", label: "Pattern (comma-separated)", placeholder: "e.g. striped, plain" },
                                    { key: "fit", label: "Fit", placeholder: "e.g. slim" },
                                    { key: "style_tags", label: "Style Tags (comma-separated)", placeholder: "e.g. casual, minimalist" },
                                    { key: "occasion_tags", label: "Occasion Tags (comma-separated)", placeholder: "e.g. work, weekend" },
                                ].map(({ key, label, placeholder }) => (
                                    <div key={key} className="space-y-1">
                                        <Label className="text-xs text-slate-400">{label}</Label>
                                        <Input
                                            placeholder={placeholder}
                                            value={createForm[key] || ""}
                                            onChange={(e) => setCreateForm({ ...createForm, [key]: e.target.value })}
                                            className="bg-slate-800 border-slate-700 text-slate-100 placeholder:text-slate-500 text-sm"
                                        />
                                    </div>
                                ))}
                                <div className="md:col-span-2 space-y-1">
                                    <Label className="text-xs text-slate-400">Image URL *</Label>
                                    <Input
                                        placeholder="https://..."
                                        value={createForm.image_url || ""}
                                        onChange={(e) => setCreateForm({ ...createForm, image_url: e.target.value })}
                                        className="bg-slate-800 border-slate-700 text-slate-100 placeholder:text-slate-500 text-sm"
                                    />
                                </div>
                                <div className="md:col-span-2">
                                    <Button type="submit" disabled={createLoading} className="bg-indigo-600 hover:bg-indigo-700">
                                        {createLoading ? <><Loader2 className="w-4 h-4 animate-spin mr-2" />Creating...</> : "Create Item"}
                                    </Button>
                                </div>
                            </form>
                        </CardContent>
                    </Card>
                </TabsContent>
            </Tabs>

            {/* Delete confirmation dialog */}
            <Dialog open={!!deleteTarget} onOpenChange={(open) => !open && setDeleteTarget(null)}>
                <DialogContent className="bg-slate-900 border-slate-700 text-slate-100">
                    <DialogHeader>
                        <DialogTitle>Delete Wardrobe Item</DialogTitle>
                        <DialogDescription className="text-slate-400">
                            This will soft-delete the item. Are you sure?
                            {deleteTarget && <span className="block mt-1 text-xs font-mono text-slate-500">{deleteTarget.id}</span>}
                        </DialogDescription>
                    </DialogHeader>
                    <DialogFooter>
                        <Button variant="outline" onClick={() => setDeleteTarget(null)} className="border-slate-600 text-slate-300 hover:bg-slate-800">
                            Cancel
                        </Button>
                        <Button variant="destructive" onClick={handleDelete} disabled={deleteLoading}>
                            {deleteLoading ? <Loader2 className="w-4 h-4 animate-spin mr-2" /> : null}
                            Delete
                        </Button>
                    </DialogFooter>
                </DialogContent>
            </Dialog>
        </div>
    );
}
