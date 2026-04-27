"use client";

import { useState, useRef, useEffect } from "react";
import { searchCatalog, getSimilarItems, requestCatalogImageUpload, createCatalogItem, getCatalogFilterOptions } from "@/lib/api";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import {
    Table, TableBody, TableCell, TableHead, TableHeader, TableRow,
} from "@/components/ui/table";
import { Alert, AlertDescription } from "@/components/ui/alert";
import { Skeleton } from "@/components/ui/skeleton";
import { Search, Loader2, AlertCircle, ChevronLeft, ChevronRight, Image, Upload, X } from "lucide-react";
import { toast } from "sonner";

const LIMIT = 20;

const FILTER_FIELDS = [
    { key: "category", label: "Category", optionsKey: "categories" },
    { key: "brand",    label: "Brand",    optionsKey: "brands" },
    { key: "gender",   label: "Gender",   optionsKey: "genders" },
    { key: "color",    label: "Color",    optionsKey: "colors" },
    { key: "style",    label: "Style",    optionsKey: "style_tags" },
    { key: "fit",      label: "Fit",      optionsKey: "fits" },
];

function CatalogFilters({ filters, onChange, onSearch, loading, filterOptions }) {
    return (
        <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-7 gap-3 mb-4">
            {FILTER_FIELDS.map(({ key, label, optionsKey }) => {
                const options = filterOptions?.[optionsKey] ?? [];
                return (
                    <div key={key} className="space-y-1">
                        <Label className="text-xs text-slate-400">{label}</Label>
                        <select
                            value={filters[key] || ""}
                            onChange={(e) => onChange({ ...filters, [key]: e.target.value })}
                            className="w-full h-8 px-2 text-sm rounded-md bg-slate-800 border border-slate-700 text-slate-100 focus:outline-none focus:ring-1 focus:ring-indigo-500"
                        >
                            <option value="">All</option>
                            {options.map((opt) => (
                                <option key={opt} value={opt}>{opt}</option>
                            ))}
                        </select>
                    </div>
                );
            })}
            <div className="flex items-end">
                <Button onClick={onSearch} disabled={loading} size="sm" className="w-full bg-indigo-600 hover:bg-indigo-700">
                    {loading ? <Loader2 className="w-3 h-3 animate-spin" /> : <Search className="w-3 h-3 mr-1" />}
                    Search
                </Button>
            </div>
        </div>
    );
}

const ALLOWED_IMAGE_TYPES = ["image/jpeg", "image/png", "image/webp"];
const MAX_FILE_SIZE = 10 * 1024 * 1024; // 10 MB

const EMPTY_FORM = {
    ref_code: "", brand: "", gender: "", category: "", subtype: "",
    name: "", color: "", pattern: "", fit: "",
    style_tags: "", product_url: "",
};

function CreateCatalogForm({ onCreated }) {
    const [form, setForm] = useState(EMPTY_FORM);
    const [imageFile, setImageFile] = useState(null);
    const [imagePreview, setImagePreview] = useState(null);
    const [uploadedImageUrl, setUploadedImageUrl] = useState(null);
    const [stage, setStage] = useState("idle"); // idle | uploading | submitting | done
    const [stageError, setStageError] = useState(null);
    const fileInputRef = useRef(null);

    function handleField(e) {
        setForm((f) => ({ ...f, [e.target.name]: e.target.value }));
    }

    function handleFileChange(e) {
        const file = e.target.files?.[0];
        if (!file) return;

        if (!ALLOWED_IMAGE_TYPES.includes(file.type)) {
            toast.error("Only JPEG, PNG, and WebP images are supported.");
            return;
        }
        if (file.size > MAX_FILE_SIZE) {
            toast.error("Image must be smaller than 10 MB.");
            return;
        }

        setImageFile(file);
        setUploadedImageUrl(null);
        setImagePreview(URL.createObjectURL(file));
    }

    function resetForm() {
        setForm(EMPTY_FORM);
        setImageFile(null);
        setImagePreview(null);
        setUploadedImageUrl(null);
        setStage("idle");
        setStageError(null);
        if (fileInputRef.current) fileInputRef.current.value = "";
    }

    async function handleSubmit(e) {
        e.preventDefault();
        setStageError(null);

        if (!imageFile && !uploadedImageUrl) {
            toast.error("Please select an image to upload.");
            return;
        }

        let finalImageUrl = uploadedImageUrl;

        // Step 1: request presigned upload target and PUT to S3
        if (imageFile) {
            setStage("uploading");
            let target;
            try {
                target = await requestCatalogImageUpload({
                    brand: form.brand || "unknown",
                    filename: imageFile.name,
                    content_type: imageFile.type,
                    file_size: imageFile.size,
                });
            } catch (err) {
                setStageError(`Upload target request failed: ${err.message}`);
                setStage("idle");
                toast.error(`Upload target request failed: ${err.message}`);
                return;
            }

            try {
                const putRes = await fetch(target.upload_url, {
                    method: "PUT",
                    headers: { "Content-Type": imageFile.type },
                    body: imageFile,
                });
                if (!putRes.ok) throw new Error(`S3 upload failed (HTTP ${putRes.status})`);
            } catch (err) {
                setStageError(`S3 upload failed: ${err.message}`);
                setStage("idle");
                toast.error(`S3 upload failed: ${err.message}`);
                return;
            }

            finalImageUrl = target.image_url;
            setUploadedImageUrl(finalImageUrl);
        }

        // Step 2: create catalog item
        setStage("submitting");
        const payload = {
            ...Object.fromEntries(Object.entries(form).filter(([, v]) => v !== "")),
            image_front_url: finalImageUrl,
        };
        // Convert comma-separated fields to arrays
        if (payload.color) payload.color = payload.color.split(",").map((s) => s.trim()).filter(Boolean);
        if (payload.style_tags) payload.style_tags = payload.style_tags.split(",").map((s) => s.trim()).filter(Boolean);

        try {
            await createCatalogItem(payload);
            toast.success("Catalog item created.");
            setStage("done");
            resetForm();
            onCreated?.();
        } catch (err) {
            setStageError(`Catalog create failed: ${err.message}`);
            setStage("idle");
            toast.error(`Catalog create failed: ${err.message}`);
        }
    }

    const isLoading = stage === "uploading" || stage === "submitting";

    return (
        <form onSubmit={handleSubmit} className="space-y-5">
            {/* Image picker */}
            <div className="space-y-2">
                <Label className="text-xs text-slate-400">Product Image *</Label>
                <div className="flex gap-3 items-start">
                    <div
                        className="w-24 h-24 rounded-md border border-slate-700 bg-slate-800 flex items-center justify-center overflow-hidden cursor-pointer shrink-0"
                        onClick={() => fileInputRef.current?.click()}
                    >
                        {imagePreview ? (
                            <img src={imagePreview} alt="preview" className="w-full h-full object-cover" />
                        ) : (
                            <Image className="w-8 h-8 text-slate-600" />
                        )}
                    </div>
                    <div className="flex-1 space-y-1">
                        <input
                            ref={fileInputRef}
                            type="file"
                            accept="image/jpeg,image/png,image/webp"
                            className="hidden"
                            onChange={handleFileChange}
                        />
                        <Button
                            type="button"
                            variant="outline"
                            size="sm"
                            className="border-slate-700 text-slate-300 hover:bg-slate-800"
                            onClick={() => fileInputRef.current?.click()}
                        >
                            <Upload className="w-3 h-3 mr-1" /> Choose image
                        </Button>
                        {imageFile && (
                            <p className="text-xs text-slate-400">{imageFile.name} ({(imageFile.size / 1024).toFixed(0)} KB)</p>
                        )}
                        {uploadedImageUrl && (
                            <p className="text-xs text-emerald-400 break-all">Uploaded: {uploadedImageUrl}</p>
                        )}
                    </div>
                </div>
            </div>

            {/* Metadata fields */}
            <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                {[
                    { name: "brand", label: "Brand *", required: true },
                    { name: "name", label: "Name *", required: true },
                    { name: "gender", label: "Gender *", required: true },
                    { name: "category", label: "Category *", required: true },
                    { name: "subtype", label: "Subtype" },
                    { name: "ref_code", label: "Ref Code" },
                    { name: "fit", label: "Fit" },
                    { name: "pattern", label: "Pattern" },
                    { name: "product_url", label: "Product URL" },
                ].map(({ name, label, required }) => (
                    <div key={name} className="space-y-1">
                        <Label className="text-xs text-slate-400">{label}</Label>
                        {name === "gender" ? (
                            <select
                                name="gender"
                                value={form.gender}
                                onChange={handleField}
                                required
                                className="w-full h-8 px-2 text-sm rounded-md bg-slate-800 border border-slate-700 text-slate-100 focus:outline-none focus:ring-1 focus:ring-indigo-500"
                            >
                                <option value="">Select gender</option>
                                <option value="women">Women</option>
                                <option value="men">Men</option>
                            </select>
                        ) : (
                            <Input
                                name={name}
                                value={form[name]}
                                onChange={handleField}
                                required={required}
                                className="bg-slate-800 border-slate-700 text-slate-100 placeholder:text-slate-500 h-8 text-sm"
                            />
                        )}
                    </div>
                ))}
                <div className="space-y-1">
                    <Label className="text-xs text-slate-400">Color (comma-separated)</Label>
                    <Input
                        name="color"
                        value={form.color}
                        onChange={handleField}
                        placeholder="black, white"
                        className="bg-slate-800 border-slate-700 text-slate-100 placeholder:text-slate-500 h-8 text-sm"
                    />
                </div>
                <div className="space-y-1">
                    <Label className="text-xs text-slate-400">Style Tags (comma-separated)</Label>
                    <Input
                        name="style_tags"
                        value={form.style_tags}
                        onChange={handleField}
                        placeholder="casual, minimal"
                        className="bg-slate-800 border-slate-700 text-slate-100 placeholder:text-slate-500 h-8 text-sm"
                    />
                </div>
            </div>

            {stageError && (
                <Alert variant="destructive" className="border-red-800 bg-red-950/50">
                    <AlertCircle className="h-4 w-4" />
                    <AlertDescription className="text-red-300 text-sm">{stageError}</AlertDescription>
                </Alert>
            )}

            <div className="flex gap-2">
                <Button
                    type="submit"
                    disabled={isLoading}
                    className="bg-indigo-600 hover:bg-indigo-700"
                >
                    {isLoading ? (
                        <>
                            <Loader2 className="w-3 h-3 animate-spin mr-1" />
                            {stage === "uploading" ? "Uploading image…" : "Creating item…"}
                        </>
                    ) : "Create Item"}
                </Button>
                <Button
                    type="button"
                    variant="outline"
                    className="border-slate-700 text-slate-300 hover:bg-slate-800"
                    onClick={resetForm}
                    disabled={isLoading}
                >
                    <X className="w-3 h-3 mr-1" /> Reset
                </Button>
            </div>
        </form>
    );
}

export default function CatalogPage() {
    const [filters, setFilters] = useState({});
    const [filterOptions, setFilterOptions] = useState(null);
    const [results, setResults] = useState(null);
    const [loading, setLoading] = useState(false);
    const [offset, setOffset] = useState(0);
    const [selectedItem, setSelectedItem] = useState(null);
    const [similar, setSimilar] = useState(null);
    const [similarLoading, setSimilarLoading] = useState(false);
    const [simItemId, setSimItemId] = useState("");
    const [simLimit, setSimLimit] = useState(10);
    const [simSource, setSimSource] = useState("catalog");
    const [lightboxUrl, setLightboxUrl] = useState(null);

    useEffect(() => {
        handleSearch(0);
        getCatalogFilterOptions().then(setFilterOptions).catch(() => {});
    }, []);

    async function handleSearch(newOffset = 0) {
        setLoading(true);
        try {
            const data = await searchCatalog({ ...filters, limit: LIMIT, offset: newOffset });
            setResults(data);
            setOffset(newOffset);
        } catch (err) {
            toast.error(err.message);
        } finally {
            setLoading(false);
        }
    }

    async function handleSimilar() {
        if (!simItemId.trim()) { toast.error("Enter an item ID"); return; }
        setSimilarLoading(true);
        setSimilar(null);
        try {
            const data = await getSimilarItems(simItemId.trim(), simLimit, simSource);
            // Similar endpoint now returns {items, total} envelope
            setSimilar(data?.items ?? data);
        } catch (err) {
            toast.error(err.message);
        } finally {
            setSimilarLoading(false);
        }
    }

    const total = results?.total ?? 0;
    const totalPages = Math.ceil(total / LIMIT);
    const currentPage = Math.floor(offset / LIMIT) + 1;

    return (
        <div className="space-y-6">
            <div>
                <h1 className="text-2xl font-bold text-white">Catalog</h1>
                <p className="text-slate-400 mt-1">Search and find similar catalog items</p>
            </div>

            <Tabs defaultValue="search">
                <TabsList className="bg-slate-800 border-slate-700">
                    <TabsTrigger value="search" className="data-[state=active]:bg-indigo-600 data-[state=active]:text-white">Search</TabsTrigger>
                    <TabsTrigger value="similar" className="data-[state=active]:bg-indigo-600 data-[state=active]:text-white">Similar Items</TabsTrigger>
                    <TabsTrigger value="manage" className="data-[state=active]:bg-indigo-600 data-[state=active]:text-white">Manage</TabsTrigger>
                </TabsList>

                <TabsContent value="search" className="mt-4 space-y-4">
                    <Card className="bg-slate-900 border-slate-800 p-4">
                        <CatalogFilters filters={filters} onChange={setFilters} onSearch={() => handleSearch(0)} loading={loading} filterOptions={filterOptions} />
                    </Card>

                    {loading && (
                        <div className="space-y-2">
                            {Array.from({ length: 5 }).map((_, i) => (
                                <Skeleton key={i} className="h-14 w-full bg-slate-800 rounded-md" />
                            ))}
                        </div>
                    )}

                    {results && !loading && (
                        <>
                            <div className="flex items-center justify-between text-sm text-slate-400">
                                <span>{total} items found</span>
                                {totalPages > 1 && (
                                    <div className="flex items-center gap-2">
                                        <Button
                                            variant="outline" size="sm"
                                            disabled={currentPage === 1}
                                            onClick={() => handleSearch(offset - LIMIT)}
                                            className="border-slate-700 text-slate-300 hover:bg-slate-800 h-7"
                                        >
                                            <ChevronLeft className="w-3 h-3" />
                                        </Button>
                                        <span>Page {currentPage} / {totalPages}</span>
                                        <Button
                                            variant="outline" size="sm"
                                            disabled={currentPage === totalPages}
                                            onClick={() => handleSearch(offset + LIMIT)}
                                            className="border-slate-700 text-slate-300 hover:bg-slate-800 h-7"
                                        >
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
                                            <TableHead className="text-slate-400">Name</TableHead>
                                            <TableHead className="text-slate-400">Brand</TableHead>
                                            <TableHead className="text-slate-400">Gender</TableHead>
                                            <TableHead className="text-slate-400">Category</TableHead>
                                            <TableHead className="text-slate-400">Color</TableHead>
                                            <TableHead className="text-slate-400">Fit</TableHead>
                                            <TableHead className="text-slate-400">Style Tags</TableHead>
                                            <TableHead className="text-slate-400 text-right">ID</TableHead>
                                        </TableRow>
                                    </TableHeader>
                                    <TableBody>
                                        {results.items.map((item) => (
                                            <TableRow key={item.id} className="border-slate-800 hover:bg-slate-800/50">
                                                <TableCell>
                                                    {item.image_front_url ? (
                                                        <img
                                                            src={item.image_front_url}
                                                            alt={item.name}
                                                            className="w-10 h-10 object-cover rounded border border-slate-700 cursor-pointer hover:opacity-80 transition-opacity"
                                                            onClick={() => setLightboxUrl(item.image_front_url)}
                                                            onError={(e) => { e.target.style.display = "none"; }}
                                                        />
                                                    ) : (
                                                        <div className="w-10 h-10 bg-slate-800 rounded border border-slate-700 flex items-center justify-center">
                                                            <Image className="w-4 h-4 text-slate-600" />
                                                        </div>
                                                    )}
                                                </TableCell>
                                                <TableCell className="text-slate-100 font-medium text-sm">{item.name}</TableCell>
                                                <TableCell className="text-slate-300 text-sm">{item.brand}</TableCell>
                                                <TableCell className="text-slate-300 text-sm capitalize">{item.gender || "—"}</TableCell>
                                                <TableCell>
                                                    <Badge variant="outline" className="border-slate-600 text-slate-300 text-xs">{item.category}</Badge>
                                                </TableCell>
                                                <TableCell className="text-slate-300 text-xs">{item.color?.join(", ") || "—"}</TableCell>
                                                <TableCell className="text-slate-400 text-xs">{item.fit || "—"}</TableCell>
                                                <TableCell>
                                                    <div className="flex flex-wrap gap-1">
                                                        {item.style_tags?.slice(0, 3).map((t) => (
                                                            <Badge key={t} variant="secondary" className="text-[10px] px-1.5 py-0 bg-slate-700 text-slate-300">{t}</Badge>
                                                        ))}
                                                    </div>
                                                </TableCell>
                                                <TableCell className="text-right">
                                                    <span className="text-[10px] font-mono text-slate-500 select-all">{item.id}</span>
                                                </TableCell>
                                            </TableRow>
                                        ))}
                                    </TableBody>
                                </Table>
                            </div>
                        </>
                    )}
                </TabsContent>

                <TabsContent value="similar" className="mt-4 space-y-4">
                    <Card className="bg-slate-900 border-slate-800 p-4">
                        <div className="grid grid-cols-1 md:grid-cols-4 gap-3">
                            <div className="md:col-span-2 space-y-1">
                                <Label className="text-xs text-slate-400">Item ID</Label>
                                <Input
                                    placeholder="Paste catalog item UUID"
                                    value={simItemId}
                                    onChange={(e) => setSimItemId(e.target.value)}
                                    className="bg-slate-800 border-slate-700 text-slate-100 placeholder:text-slate-500 text-sm"
                                />
                            </div>
                            <div className="space-y-1">
                                <Label className="text-xs text-slate-400">Source</Label>
                                <select
                                    value={simSource}
                                    onChange={(e) => setSimSource(e.target.value)}
                                    className="w-full h-10 px-3 text-sm rounded-md bg-slate-800 border border-slate-700 text-slate-100"
                                >
                                    <option value="catalog">Catalog</option>
                                    <option value="wardrobe">Wardrobe</option>
                                    <option value="both">Both</option>
                                </select>
                            </div>
                            <div className="space-y-1">
                                <Label className="text-xs text-slate-400">Limit</Label>
                                <div className="flex gap-2">
                                    <Input
                                        type="number" min={1} max={50}
                                        value={simLimit}
                                        onChange={(e) => setSimLimit(Number(e.target.value))}
                                        className="bg-slate-800 border-slate-700 text-slate-100 text-sm"
                                    />
                                    <Button onClick={handleSimilar} disabled={similarLoading} className="bg-indigo-600 hover:bg-indigo-700 shrink-0">
                                        {similarLoading ? <Loader2 className="w-4 h-4 animate-spin" /> : "Find"}
                                    </Button>
                                </div>
                            </div>
                        </div>
                    </Card>

                    {similar && (
                        <div className="rounded-md border border-slate-800 overflow-hidden">
                            <Table>
                                <TableHeader>
                                    <TableRow className="border-slate-800 hover:bg-transparent">
                                        <TableHead className="text-slate-400 w-16">Image</TableHead>
                                        <TableHead className="text-slate-400">Name</TableHead>
                                        <TableHead className="text-slate-400">Category</TableHead>
                                        <TableHead className="text-slate-400 text-right">Similarity</TableHead>
                                        <TableHead className="text-slate-400 text-right">ID</TableHead>
                                    </TableRow>
                                </TableHeader>
                                <TableBody>
                                    {similar.length === 0 ? (
                                        <TableRow>
                                            <TableCell colSpan={5} className="text-center text-slate-500 py-8">No similar items found</TableCell>
                                        </TableRow>
                                    ) : similar.map((item) => (
                                        <TableRow key={item.id} className="border-slate-800 hover:bg-slate-800/50">
                                            <TableCell>
                                                {item.image_front_url ? (
                                                    <img
                                                        src={item.image_front_url}
                                                        alt={item.name}
                                                        className="w-10 h-10 object-cover rounded border border-slate-700 cursor-pointer hover:opacity-80 transition-opacity"
                                                        onClick={() => setLightboxUrl(item.image_front_url)}
                                                    />
                                                ) : (
                                                    <div className="w-10 h-10 bg-slate-800 rounded border border-slate-700" />
                                                )}
                                            </TableCell>
                                            <TableCell className="text-slate-100 text-sm">{item.name}</TableCell>
                                            <TableCell>
                                                <Badge variant="outline" className="border-slate-600 text-slate-300 text-xs">{item.category}</Badge>
                                            </TableCell>
                                            <TableCell className="text-right">
                                                <Badge className={item.similarity > 0.8 ? "bg-emerald-700" : item.similarity > 0.6 ? "bg-amber-700" : "bg-slate-700"}>
                                                    {(item.similarity * 100).toFixed(1)}%
                                                </Badge>
                                            </TableCell>
                                            <TableCell className="text-right">
                                                <span className="text-[10px] font-mono text-slate-500 select-all">{item.id}</span>
                                            </TableCell>
                                        </TableRow>
                                    ))}
                                </TableBody>
                            </Table>
                        </div>
                    )}
                </TabsContent>

                <TabsContent value="manage" className="mt-4">
                    <Card className="bg-slate-900 border-slate-800 p-6">
                        <CardHeader className="px-0 pt-0 pb-4">
                            <CardTitle className="text-white text-lg">Create Catalog Item</CardTitle>
                            <p className="text-slate-400 text-sm mt-1">
                                Select an image to upload to S3, then fill in the item metadata.
                            </p>
                        </CardHeader>
                        <CardContent className="px-0">
                            <CreateCatalogForm onCreated={() => handleSearch(0)} />
                        </CardContent>
                    </Card>
                </TabsContent>
            </Tabs>

            {lightboxUrl && (
                <div
                    className="fixed inset-0 z-50 flex items-center justify-center bg-black/80"
                    onClick={() => setLightboxUrl(null)}
                >
                    <button
                        className="absolute top-4 right-4 text-white bg-slate-800 hover:bg-slate-700 rounded-full w-8 h-8 flex items-center justify-center"
                        onClick={() => setLightboxUrl(null)}
                    >
                        <X className="w-4 h-4" />
                    </button>
                    <img
                        src={lightboxUrl}
                        alt="Product preview"
                        className="max-w-[90vw] max-h-[90vh] object-contain rounded shadow-2xl"
                        onClick={(e) => e.stopPropagation()}
                    />
                </div>
            )}
        </div>
    );
}
