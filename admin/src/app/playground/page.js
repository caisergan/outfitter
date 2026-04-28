"use client";

import { useEffect, useState } from "react";
import {
    searchCatalog,
    getCatalogFilterOptions,
    generatePlaygroundImage,
} from "@/lib/api";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Textarea } from "@/components/ui/textarea";
import { Alert, AlertDescription } from "@/components/ui/alert";
import { Skeleton } from "@/components/ui/skeleton";
import {
    Sparkles,
    Search,
    Loader2,
    AlertCircle,
    ChevronLeft,
    ChevronRight,
    ChevronDown,
    ChevronUp,
    Check,
    X,
    Download,
    Image as ImageIcon,
} from "lucide-react";
import { toast } from "sonner";

const LIMIT = 20;
const MAX_SELECTED = 16;

const FILTER_FIELDS = [
    { key: "category", label: "Category", optionsKey: "categories" },
    { key: "brand", label: "Brand", optionsKey: "brands" },
    { key: "gender", label: "Gender", optionsKey: "genders" },
    { key: "color", label: "Color", optionsKey: "colors" },
    { key: "style", label: "Style", optionsKey: "style_tags" },
    { key: "fit", label: "Fit", optionsKey: "fits" },
];

const SIZE_OPTIONS = [
    { value: "1024x1536", label: "Portrait (1024×1536)" },
    { value: "1024x1024", label: "Square (1024×1024)" },
    { value: "1536x1024", label: "Landscape (1536×1024)" },
];

const QUALITY_OPTIONS = [
    { value: "high", label: "High" },
    { value: "medium", label: "Medium" },
    { value: "low", label: "Low" },
];

export default function PlaygroundPage() {
    // catalog
    const [filters, setFilters] = useState({});
    const [filterOptions, setFilterOptions] = useState(null);
    const [results, setResults] = useState(null);
    const [offset, setOffset] = useState(0);
    const [loading, setLoading] = useState(false);

    // selection
    const [selected, setSelected] = useState(new Map());

    // prompt + params
    const [prompt, setPrompt] = useState("");
    const [size, setSize] = useState("1024x1536");
    const [quality, setQuality] = useState("high");
    const [count, setCount] = useState(1);
    const [advancedOpen, setAdvancedOpen] = useState(false);

    // generation
    const [generating, setGenerating] = useState(false);
    const [generatedImages, setGeneratedImages] = useState([]);
    const [genError, setGenError] = useState(null);

    useEffect(() => {
        runSearch(0);
        getCatalogFilterOptions().then(setFilterOptions).catch(() => {});
    }, []);

    async function runSearch(newOffset) {
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

    function toggleSelect(item) {
        setSelected((prev) => {
            const next = new Map(prev);
            if (next.has(item.id)) {
                next.delete(item.id);
                return next;
            }
            if (next.size >= MAX_SELECTED) {
                toast.error(`Maximum ${MAX_SELECTED} items can be selected`);
                return prev;
            }
            next.set(item.id, item);
            return next;
        });
    }

    function clearSelection() {
        setSelected(new Map());
    }

    async function handleGenerate() {
        setGenError(null);
        setGeneratedImages([]);
        if (selected.size === 0) {
            toast.error("Pick at least one catalog item");
            return;
        }
        if (!prompt.trim()) {
            toast.error("Prompt cannot be empty");
            return;
        }
        setGenerating(true);
        try {
            const data = await generatePlaygroundImage({
                catalog_item_ids: Array.from(selected.keys()),
                prompt,
                size,
                quality,
                n: count,
            });
            setGeneratedImages(data.images);
            toast.success(`Generated ${data.images.length} image(s) in ${data.elapsed_ms}ms`);
        } catch (err) {
            setGenError(err.message);
            toast.error(err.message);
        } finally {
            setGenerating(false);
        }
    }

    function downloadImage(dataUrl, index) {
        const link = document.createElement("a");
        link.href = dataUrl;
        link.download = `playground-${Date.now()}-${index}.png`;
        link.click();
    }

    const total = results?.total ?? 0;
    const totalPages = Math.ceil(total / LIMIT);
    const currentPage = Math.floor(offset / LIMIT) + 1;
    const canGenerate = selected.size > 0 && prompt.trim().length > 0 && !generating;

    return (
        <div className="space-y-6">
            <div>
                <h1 className="text-2xl font-bold text-white flex items-center gap-2">
                    <Sparkles className="w-5 h-5 text-indigo-400" />
                    Playground
                </h1>
                <p className="text-slate-400 mt-1">
                    Pick catalog items, write a prompt, and generate images via gpt-image-2.
                    Nothing here is persisted.
                </p>
            </div>

            {/* Selected items rail */}
            <Card className="bg-slate-900 border-slate-800 p-3 sticky top-0 z-10">
                <div className="flex items-center justify-between gap-3 mb-2">
                    <p className="text-xs text-slate-400">
                        Selected: {selected.size} / {MAX_SELECTED}
                    </p>
                    {selected.size > 0 && (
                        <Button
                            size="sm"
                            variant="outline"
                            onClick={clearSelection}
                            className="border-slate-700 text-slate-300 hover:bg-slate-800 h-7"
                        >
                            <X className="w-3 h-3 mr-1" /> Clear all
                        </Button>
                    )}
                </div>
                {selected.size === 0 ? (
                    <p className="text-xs text-slate-500 italic">No items selected yet.</p>
                ) : (
                    <div className="flex gap-2 overflow-x-auto pb-1">
                        {Array.from(selected.values()).map((item) => (
                            <div key={item.id} className="relative shrink-0 w-16 h-16">
                                <img
                                    src={item.image_front_url}
                                    alt={item.name}
                                    className="w-full h-full object-cover rounded border border-slate-700"
                                />
                                <button
                                    onClick={() => toggleSelect(item)}
                                    className="absolute -top-1 -right-1 w-5 h-5 rounded-full bg-slate-800 border border-slate-600 text-slate-200 hover:bg-red-700 flex items-center justify-center"
                                    aria-label={`Remove ${item.name}`}
                                >
                                    <X className="w-3 h-3" />
                                </button>
                            </div>
                        ))}
                    </div>
                )}
            </Card>

            {/* Catalog picker */}
            <Card className="bg-slate-900 border-slate-800 p-4 space-y-4">
                <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-7 gap-3">
                    {FILTER_FIELDS.map(({ key, label, optionsKey }) => {
                        const options = filterOptions?.[optionsKey] ?? [];
                        return (
                            <div key={key} className="space-y-1">
                                <Label className="text-xs text-slate-400">{label}</Label>
                                <select
                                    value={filters[key] || ""}
                                    onChange={(e) => setFilters({ ...filters, [key]: e.target.value })}
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
                        <Button
                            size="sm"
                            onClick={() => runSearch(0)}
                            disabled={loading}
                            className="w-full bg-indigo-600 hover:bg-indigo-700"
                        >
                            {loading ? <Loader2 className="w-3 h-3 animate-spin" /> : <Search className="w-3 h-3 mr-1" />}
                            Search
                        </Button>
                    </div>
                </div>

                {loading && (
                    <div className="grid grid-cols-2 sm:grid-cols-4 md:grid-cols-6 gap-3">
                        {Array.from({ length: 12 }).map((_, i) => (
                            <Skeleton key={i} className="aspect-square w-full bg-slate-800 rounded-md" />
                        ))}
                    </div>
                )}

                {!loading && results && (
                    <>
                        <div className="grid grid-cols-2 sm:grid-cols-4 md:grid-cols-6 gap-3">
                            {results.items.map((item) => {
                                const isSelected = selected.has(item.id);
                                return (
                                    <button
                                        key={item.id}
                                        onClick={() => toggleSelect(item)}
                                        className={`relative group rounded-md overflow-hidden border transition-all text-left ${
                                            isSelected
                                                ? "border-indigo-500 ring-2 ring-indigo-500"
                                                : "border-slate-700 hover:border-slate-500"
                                        }`}
                                    >
                                        <div className="aspect-square bg-slate-800">
                                            {item.image_front_url ? (
                                                <img
                                                    src={item.image_front_url}
                                                    alt={item.name}
                                                    className="w-full h-full object-cover"
                                                />
                                            ) : (
                                                <div className="w-full h-full flex items-center justify-center">
                                                    <ImageIcon className="w-6 h-6 text-slate-600" />
                                                </div>
                                            )}
                                        </div>
                                        {isSelected && (
                                            <div className="absolute top-1 right-1 w-5 h-5 rounded-full bg-indigo-600 flex items-center justify-center">
                                                <Check className="w-3 h-3 text-white" />
                                            </div>
                                        )}
                                        <div className="p-2 bg-slate-900">
                                            <p className="text-xs text-slate-100 truncate">{item.name}</p>
                                            <p className="text-[10px] text-slate-500 truncate">{item.brand}</p>
                                        </div>
                                    </button>
                                );
                            })}
                        </div>

                        {totalPages > 1 && (
                            <div className="flex items-center justify-between text-sm text-slate-400">
                                <span>{total} items</span>
                                <div className="flex items-center gap-2">
                                    <Button
                                        variant="outline"
                                        size="sm"
                                        disabled={currentPage === 1}
                                        onClick={() => runSearch(offset - LIMIT)}
                                        className="border-slate-700 text-slate-300 hover:bg-slate-800 h-7"
                                    >
                                        <ChevronLeft className="w-3 h-3" />
                                    </Button>
                                    <span>Page {currentPage} / {totalPages}</span>
                                    <Button
                                        variant="outline"
                                        size="sm"
                                        disabled={currentPage === totalPages}
                                        onClick={() => runSearch(offset + LIMIT)}
                                        className="border-slate-700 text-slate-300 hover:bg-slate-800 h-7"
                                    >
                                        <ChevronRight className="w-3 h-3" />
                                    </Button>
                                </div>
                            </div>
                        )}
                    </>
                )}
            </Card>

            {/* Prompt */}
            <Card className="bg-slate-900 border-slate-800 p-4 space-y-2">
                <Label className="text-xs text-slate-400">Prompt</Label>
                <Textarea
                    value={prompt}
                    onChange={(e) => setPrompt(e.target.value)}
                    rows={6}
                    placeholder="Describe how to render the selected items. e.g. 'Place these clothes on a young woman walking down a Paris street, photorealistic, golden hour.'"
                    className="bg-slate-800 border-slate-700 text-slate-100 placeholder:text-slate-500 resize-none"
                />
                <p className="text-xs text-slate-500">{prompt.length} / 2000</p>
            </Card>

            {/* Advanced */}
            <Card className="bg-slate-900 border-slate-800 p-4">
                <button
                    onClick={() => setAdvancedOpen((v) => !v)}
                    className="flex items-center gap-2 text-sm text-slate-300 hover:text-white"
                    aria-expanded={advancedOpen}
                >
                    {advancedOpen ? <ChevronUp className="w-4 h-4" /> : <ChevronDown className="w-4 h-4" />}
                    Advanced
                </button>

                {advancedOpen && (
                    <div className="grid grid-cols-1 md:grid-cols-3 gap-3 mt-3">
                        <div className="space-y-1">
                            <Label className="text-xs text-slate-400">Size</Label>
                            <select
                                value={size}
                                onChange={(e) => setSize(e.target.value)}
                                className="w-full h-9 px-2 text-sm rounded-md bg-slate-800 border border-slate-700 text-slate-100"
                            >
                                {SIZE_OPTIONS.map((o) => (
                                    <option key={o.value} value={o.value}>{o.label}</option>
                                ))}
                            </select>
                        </div>
                        <div className="space-y-1">
                            <Label className="text-xs text-slate-400">Quality</Label>
                            <select
                                value={quality}
                                onChange={(e) => setQuality(e.target.value)}
                                className="w-full h-9 px-2 text-sm rounded-md bg-slate-800 border border-slate-700 text-slate-100"
                            >
                                {QUALITY_OPTIONS.map((o) => (
                                    <option key={o.value} value={o.value}>{o.label}</option>
                                ))}
                            </select>
                        </div>
                        <div className="space-y-1">
                            <Label className="text-xs text-slate-400">Count</Label>
                            <Input
                                type="number"
                                min={1}
                                max={4}
                                value={count}
                                onChange={(e) =>
                                    setCount(Math.max(1, Math.min(4, Number(e.target.value) || 1)))
                                }
                                className="bg-slate-800 border-slate-700 text-slate-100 h-9 text-sm"
                            />
                        </div>
                    </div>
                )}
            </Card>

            {/* Generate */}
            <div>
                <Button
                    onClick={handleGenerate}
                    disabled={!canGenerate}
                    className="bg-indigo-600 hover:bg-indigo-700 disabled:opacity-40"
                >
                    {generating ? (
                        <><Loader2 className="w-4 h-4 animate-spin mr-2" /> Generating…</>
                    ) : (
                        <><Sparkles className="w-4 h-4 mr-2" /> Generate</>
                    )}
                </Button>
            </div>

            {/* Result */}
            {(generating || generatedImages.length > 0 || genError) && (
                <Card className="bg-slate-900 border-slate-800 p-4 space-y-3">
                    <CardTitle className="text-sm font-medium text-slate-300">Result</CardTitle>
                    {generating && (
                        <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                            {Array.from({ length: count }).map((_, i) => (
                                <Skeleton key={i} className="aspect-[2/3] w-full bg-slate-800 rounded-md" />
                            ))}
                        </div>
                    )}
                    {!generating && generatedImages.length > 0 && (
                        <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                            {generatedImages.map((dataUrl, i) => (
                                <div key={i} className="space-y-2">
                                    <img
                                        src={dataUrl}
                                        alt={`Generated ${i + 1}`}
                                        className="w-full rounded-md border border-slate-700"
                                    />
                                    <Button
                                        variant="outline"
                                        size="sm"
                                        onClick={() => downloadImage(dataUrl, i)}
                                        className="border-slate-700 text-slate-300 hover:bg-slate-800"
                                    >
                                        <Download className="w-3 h-3 mr-1" /> Download
                                    </Button>
                                </div>
                            ))}
                        </div>
                    )}
                    {!generating && genError && (
                        <Alert variant="destructive" className="bg-red-950 border-red-800">
                            <AlertCircle className="h-4 w-4" />
                            <AlertDescription>{genError}</AlertDescription>
                        </Alert>
                    )}
                </Card>
            )}
        </div>
    );
}
