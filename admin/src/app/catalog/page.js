"use client";

import { useState } from "react";
import { searchCatalog, getSimilarItems } from "@/lib/api";
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
import { Search, Loader2, AlertCircle, ChevronLeft, ChevronRight, Image } from "lucide-react";
import { toast } from "sonner";

const LIMIT = 20;

function CatalogFilters({ filters, onChange, onSearch, loading }) {
    return (
        <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-6 gap-3 mb-4">
            {["category", "brand", "color", "style", "fit"].map((field) => (
                <div key={field} className="space-y-1">
                    <Label className="text-xs text-slate-400 capitalize">{field}</Label>
                    <Input
                        placeholder={field}
                        value={filters[field] || ""}
                        onChange={(e) => onChange({ ...filters, [field]: e.target.value })}
                        className="bg-slate-800 border-slate-700 text-slate-100 placeholder:text-slate-500 h-8 text-sm"
                    />
                </div>
            ))}
            <div className="flex items-end">
                <Button onClick={onSearch} disabled={loading} size="sm" className="w-full bg-indigo-600 hover:bg-indigo-700">
                    {loading ? <Loader2 className="w-3 h-3 animate-spin" /> : <Search className="w-3 h-3 mr-1" />}
                    Search
                </Button>
            </div>
        </div>
    );
}

export default function CatalogPage() {
    const [filters, setFilters] = useState({});
    const [results, setResults] = useState(null);
    const [loading, setLoading] = useState(false);
    const [offset, setOffset] = useState(0);
    const [selectedItem, setSelectedItem] = useState(null);
    const [similar, setSimilar] = useState(null);
    const [similarLoading, setSimilarLoading] = useState(false);
    const [simItemId, setSimItemId] = useState("");
    const [simLimit, setSimLimit] = useState(10);
    const [simSource, setSimSource] = useState("catalog");

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
            setSimilar(data);
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
                </TabsList>

                <TabsContent value="search" className="mt-4 space-y-4">
                    <Card className="bg-slate-900 border-slate-800 p-4">
                        <CatalogFilters filters={filters} onChange={setFilters} onSearch={() => handleSearch(0)} loading={loading} />
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
                                                    {item.image_url ? (
                                                        <img
                                                            src={item.image_url}
                                                            alt={item.name}
                                                            className="w-10 h-10 object-cover rounded border border-slate-700"
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
                                                {item.image_url ? (
                                                    <img src={item.image_url} alt={item.name} className="w-10 h-10 object-cover rounded border border-slate-700" />
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
            </Tabs>
        </div>
    );
}
