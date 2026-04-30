"use client";

import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import {
    searchCatalog,
    getCatalogFilterOptions,
    generatePlaygroundImage,
    fetchPlaygroundSystemPrompt,
    fetchPlaygroundTemplates,
    fetchPlaygroundPersonas,
    fetchPlaygroundRuns,
    fetchPlaygroundRun,
    getCatalogItem,
} from "@/lib/api";
import {
    GLOBAL_SYSTEM_PROMPT,
    buildFinalPrompt,
    composeUserPrompt,
} from "@/lib/prompts/editorial";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Textarea } from "@/components/ui/textarea";
import { Alert, AlertDescription } from "@/components/ui/alert";
import { Skeleton } from "@/components/ui/skeleton";
import {
    Dialog,
    DialogContent,
    DialogHeader,
    DialogTitle,
    DialogDescription,
} from "@/components/ui/dialog";
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
    RotateCcw,
    Copy,
    History,
    Eye,
    RefreshCw,
} from "lucide-react";
import { toast } from "sonner";

const LIMIT = 20;
const MAX_SELECTED = 16;
const PROMPT_CAP = 32000;
const SEARCH_DEBOUNCE_MS = 300;

const FILTER_FIELDS = [
    { key: "category", label: "Category", optionsKey: "categories" },
    { key: "subtype",  label: "Subtype",  optionsKey: "__subtypes_by_category" },
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

const TIMESTAMP_FMT = new Intl.DateTimeFormat(undefined, {
    month: "short",
    day: "numeric",
    hour: "2-digit",
    minute: "2-digit",
});

function excerpt(text, max = 90) {
    if (!text) return "";
    const firstLine = text.split("\n").find((l) => l.trim()) ?? "";
    return firstLine.length > max ? firstLine.slice(0, max - 1) + "…" : firstLine;
}

export default function PlaygroundPage() {
    // catalog
    const [filters, setFilters] = useState({});
    const [searchQuery, setSearchQuery] = useState("");
    const [debouncedQuery, setDebouncedQuery] = useState("");
    const [filterOptions, setFilterOptions] = useState(null);
    const [results, setResults] = useState(null);
    const [offset, setOffset] = useState(0);
    const [loading, setLoading] = useState(false);

    // selection
    const [selected, setSelected] = useState(new Map());

    // prompt library (server-fetched)
    const [serverSystemPrompt, setServerSystemPrompt] = useState(GLOBAL_SYSTEM_PROMPT);
    const [templates, setTemplates] = useState(null);
    // All personas fetched once. Gender filter is client-side so reproduce
    // can resolve a persona's gender from its id without a network round trip.
    const [allPersonas, setAllPersonas] = useState(null);
    const [gender, setGender] = useState("female");
    const [templateId, setTemplateId] = useState(null);
    const [personaId, setPersonaId] = useState(null);

    // prompt + params
    const [systemPrompt, setSystemPrompt] = useState(GLOBAL_SYSTEM_PROMPT);
    const [systemPromptOpen, setSystemPromptOpen] = useState(false);
    const [prompt, setPrompt] = useState("");
    const [previewOpen, setPreviewOpen] = useState(false);
    const [size, setSize] = useState("1024x1536");
    const [quality, setQuality] = useState("high");
    const [count, setCount] = useState(1);
    const [advancedOpen, setAdvancedOpen] = useState(false);

    // tracks the last composed user-prompt we wrote to the textarea so we can
    // tell whether the textarea has been manually edited (don't auto-overwrite)
    const lastAppliedComposed = useRef("");

    // generation
    const [generating, setGenerating] = useState(false);
    const [generatedImages, setGeneratedImages] = useState([]);
    const [genError, setGenError] = useState(null);

    // recent runs
    const [runs, setRuns] = useState(null);
    const [runsCursor, setRunsCursor] = useState(null);
    const [runsLoading, setRunsLoading] = useState(false);
    const [reproducing, setReproducing] = useState(false);
    const [viewingRunId, setViewingRunId] = useState(null);
    const [viewingRun, setViewingRun] = useState(null);
    const [viewingRunLoading, setViewingRunLoading] = useState(false);

    useEffect(() => {
        getCatalogFilterOptions().then(setFilterOptions).catch(() => {});
    }, []);

    // Mount-only: load the user's recent runs.
    useEffect(() => {
        let cancelled = false;
        setRunsLoading(true);
        fetchPlaygroundRuns({ limit: 10 })
            .then((data) => {
                if (cancelled) return;
                setRuns(data.items);
                setRunsCursor(data.next_cursor);
            })
            .catch((err) => {
                if (cancelled) return;
                console.error("Failed to load recent runs:", err);
                setRuns([]);
            })
            .finally(() => {
                if (!cancelled) setRunsLoading(false);
            });
        return () => {
            cancelled = true;
        };
    }, []);

    // When the View Full modal opens, fetch the full run snapshot. Re-fetches
    // even if the run is in the list because /runs/{id} returns fresh signed
    // URLs (the list may have older URLs that have already expired).
    useEffect(() => {
        if (!viewingRunId) {
            setViewingRun(null);
            return;
        }
        let cancelled = false;
        setViewingRunLoading(true);
        fetchPlaygroundRun(viewingRunId)
            .then((data) => {
                if (cancelled) return;
                setViewingRun(data);
            })
            .catch((err) => {
                if (cancelled) return;
                toast.error(err.message);
                setViewingRunId(null);
            })
            .finally(() => {
                if (!cancelled) setViewingRunLoading(false);
            });
        return () => {
            cancelled = true;
        };
    }, [viewingRunId]);

    // Mount-only: load the active system prompt, templates, and personas.
    // Personas are fetched without a gender filter so the full library is
    // available client-side for filtering and for reproducing past runs.
    // Falls back to the local GLOBAL_SYSTEM_PROMPT constant if the API is
    // unreachable so the panel stays usable offline.
    useEffect(() => {
        let cancelled = false;
        Promise.all([
            fetchPlaygroundSystemPrompt(),
            fetchPlaygroundTemplates(),
            fetchPlaygroundPersonas(),
        ])
            .then(([sp, ts, ps]) => {
                if (cancelled) return;
                setServerSystemPrompt(sp.content);
                setSystemPrompt(sp.content);
                setTemplates(ts);
                setTemplateId((prev) => prev ?? ts[0]?.id ?? null);
                setAllPersonas(ps);
                const firstFemale = ps.find((p) => p.gender === "female");
                setPersonaId((prev) => prev ?? firstFemale?.id ?? ps[0]?.id ?? null);
            })
            .catch((err) => {
                if (cancelled) return;
                console.error("Failed to load playground config:", err);
                toast.error(
                    "Could not load playground config; using local defaults",
                );
                setTemplates([]);
                setAllPersonas([]);
            });
        return () => {
            cancelled = true;
        };
    }, []);

    // Whenever gender changes, snap personaId to the first persona of that
    // gender if the current pick doesn't match. No network round trip.
    useEffect(() => {
        if (!allPersonas) return;
        const current = allPersonas.find((p) => p.id === personaId);
        if (current && current.gender === gender) return;
        const firstOfGender = allPersonas.find((p) => p.gender === gender);
        setPersonaId(firstOfGender?.id ?? null);
    }, [gender, allPersonas, personaId]);

    useEffect(() => {
        const timer = setTimeout(
            () => setDebouncedQuery(searchQuery.trim()),
            SEARCH_DEBOUNCE_MS,
        );
        return () => clearTimeout(timer);
    }, [searchQuery]);

    const runSearch = useCallback(
        async (newOffset) => {
            setLoading(true);
            try {
                const params = { ...filters, limit: LIMIT, offset: newOffset };
                if (debouncedQuery) params.q = debouncedQuery;
                const data = await searchCatalog(params);
                setResults(data);
                setOffset(newOffset);
            } catch (err) {
                toast.error(err.message);
            } finally {
                setLoading(false);
            }
        },
        [filters, debouncedQuery],
    );

    useEffect(() => {
        runSearch(0);
    }, [runSearch]);

    function handleFilterChange(key, value) {
        setFilters((prev) => {
            if (key === "category" && prev.category !== value) {
                return { ...prev, category: value, subtype: "" };
            }
            return { ...prev, [key]: value };
        });
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
        if (!finalPrompt) {
            toast.error("Prompt cannot be empty — system prompt or notes required");
            return;
        }
        if (finalPrompt.length > PROMPT_CAP) {
            toast.error(`Final prompt is ${finalPrompt.length} chars, max ${PROMPT_CAP}`);
            return;
        }
        setGenerating(true);
        try {
            const data = await generatePlaygroundImage({
                catalog_item_ids: Array.from(selected.keys()),
                system_prompt: systemPrompt,
                user_prompt: prompt,
                template_id: templateId,
                persona_id: personaId,
                size,
                quality,
                n: count,
            });
            setGeneratedImages(data.images);
            const usage =
                typeof data.daily_used === "number" && typeof data.daily_limit === "number"
                    ? ` · ${data.daily_used}/${data.daily_limit} today`
                    : "";
            toast.success(`Generated ${data.images.length} image(s) in ${data.elapsed_ms}ms${usage}`);
            refreshRunsAfterGenerate();
        } catch (err) {
            if (
                err.status === 429 &&
                err.detail?.error?.code === "DAILY_LIMIT_REACHED"
            ) {
                const { used, limit, reset_at } = err.detail.error;
                const resetTime = reset_at
                    ? new Date(reset_at).toLocaleTimeString([], {
                          hour: "2-digit",
                          minute: "2-digit",
                      })
                    : "tomorrow";
                const message = `Daily limit reached (${used}/${limit}). Resets at ${resetTime}.`;
                setGenError(message);
                toast.error(message);
            } else {
                setGenError(err.message);
                toast.error(err.message);
                // Failed runs are still persisted server-side; refresh so the
                // recent runs list reflects the failed-status row.
                if (err.status !== 429) {
                    refreshRunsAfterGenerate();
                }
            }
        } finally {
            setGenerating(false);
        }
    }

    async function loadMoreRuns() {
        if (!runsCursor || runsLoading) return;
        setRunsLoading(true);
        try {
            const data = await fetchPlaygroundRuns({
                limit: 10,
                cursor: runsCursor,
            });
            setRuns((prev) => [...(prev ?? []), ...data.items]);
            setRunsCursor(data.next_cursor);
        } catch (err) {
            toast.error(err.message);
        } finally {
            setRunsLoading(false);
        }
    }

    async function refreshRunsAfterGenerate() {
        try {
            const data = await fetchPlaygroundRuns({ limit: 10 });
            setRuns(data.items);
            setRunsCursor(data.next_cursor);
        } catch (err) {
            console.error("Failed to refresh runs:", err);
        }
    }

    async function reproduceRun(run) {
        setReproducing(true);
        try {
            // Scalars + size/quality/n
            setSize(run.size);
            setQuality(run.quality);
            setCount(run.n);

            // System prompt — assignment marks "modified" if it diverges from
            // the current server default.
            setSystemPrompt(run.system_prompt_text);

            // Template — only set if still in our cached active list.
            const tplExists = templates?.some((t) => t.id === run.template_id);
            setTemplateId(tplExists ? run.template_id : null);

            // Persona — resolve via cached allPersonas; switch gender first
            // so the visible list contains the picked persona.
            if (run.persona_id) {
                const p = allPersonas?.find((x) => x.id === run.persona_id);
                if (p) {
                    setGender(p.gender);
                    setPersonaId(p.id);
                } else {
                    setPersonaId(null);
                }
            } else {
                setPersonaId(null);
            }

            // User prompt — set to snapshot. The dirty badge then reflects
            // whether the snapshot still matches the (now-restored) dropdown
            // composition, which is the right answer either way.
            setPrompt(run.user_prompt_text);

            // Catalog selection — fetch each item by id; tolerate deletions.
            const items = await Promise.all(
                (run.catalog_item_ids || []).map((id) =>
                    getCatalogItem(id).catch(() => null),
                ),
            );
            const resolved = items.filter(Boolean);
            setSelected(new Map(resolved.map((i) => [i.id, i])));
            const missing = (run.catalog_item_ids?.length ?? 0) - resolved.length;
            if (missing > 0) {
                toast(`${missing} catalog item(s) no longer exist`, {
                    description: "Reproduced selection without them.",
                });
            }

            toast.success(`Reproduced run ${run.id.slice(0, 8)}`);
        } catch (err) {
            console.error("Reproduce failed:", err);
            toast.error(`Reproduce failed: ${err.message}`);
        } finally {
            setReproducing(false);
        }
    }

    function resetSystemPrompt() {
        setSystemPrompt(serverSystemPrompt);
        toast.success("System prompt reset to global default");
    }

    function resetUserPrompt() {
        setPrompt(composedUserPrompt);
        lastAppliedComposed.current = composedUserPrompt;
    }

    async function copyFinalPrompt() {
        try {
            await navigator.clipboard.writeText(finalPrompt);
            toast.success("Final prompt copied");
        } catch {
            toast.error("Could not copy to clipboard");
        }
    }

    function downloadImage(dataUrl, index) {
        const link = document.createElement("a");
        link.href = dataUrl;
        link.download = `playground-${Date.now()}-${index}.png`;
        link.click();
    }

    const template = useMemo(
        () => templates?.find((t) => t.id === templateId) ?? null,
        [templates, templateId],
    );
    const persona = useMemo(
        () => allPersonas?.find((p) => p.id === personaId) ?? null,
        [allPersonas, personaId],
    );
    const visiblePersonas = useMemo(
        () => allPersonas?.filter((p) => p.gender === gender) ?? null,
        [allPersonas, gender],
    );
    const composedUserPrompt = useMemo(
        () => composeUserPrompt({ template, persona }),
        [template, persona],
    );

    // Auto-update the user-prompt textarea when template/persona change, but
    // only if the user hasn't manually edited (i.e. the textarea still matches
    // the last composed value we wrote into it). Manual edits are preserved
    // until the user explicitly hits "Reset".
    useEffect(() => {
        setPrompt((prev) =>
            prev === lastAppliedComposed.current ? composedUserPrompt : prev,
        );
        lastAppliedComposed.current = composedUserPrompt;
    }, [composedUserPrompt]);

    const finalPrompt = buildFinalPrompt({
        systemPrompt,
        userPrompt: prompt,
    });
    const isSystemPromptDirty = systemPrompt !== serverSystemPrompt;
    const isUserPromptDirty =
        composedUserPrompt.length > 0 && prompt !== composedUserPrompt;

    const total = results?.total ?? 0;
    const totalPages = Math.ceil(total / LIMIT);
    const currentPage = Math.floor(offset / LIMIT) + 1;
    const canGenerate =
        selected.size > 0 &&
        finalPrompt.length > 0 &&
        finalPrompt.length <= PROMPT_CAP &&
        !generating;

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
                <div className="relative">
                    <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-500" />
                    {loading && (
                        <Loader2 className="absolute right-3 top-1/2 -translate-y-1/2 w-4 h-4 animate-spin text-slate-500" />
                    )}
                    <Input
                        type="text"
                        value={searchQuery}
                        onChange={(e) => setSearchQuery(e.target.value)}
                        placeholder="Search catalog by name…"
                        className="pl-9 pr-9 bg-slate-800 border-slate-700 text-slate-100 placeholder:text-slate-500 h-10"
                    />
                </div>
                <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-7 gap-3">
                    {FILTER_FIELDS.map(({ key, label, optionsKey }) => {
                        const options =
                            optionsKey === "__subtypes_by_category"
                                ? (filterOptions?.subtypes_by_category?.[filters.category] ?? [])
                                : (filterOptions?.[optionsKey] ?? []);
                        const isSubtype = key === "subtype";
                        const isDisabled = isSubtype && !filters.category;
                        return (
                            <div key={key} className="space-y-1">
                                <Label className="text-xs text-slate-400">{label}</Label>
                                <select
                                    value={filters[key] || ""}
                                    onChange={(e) => handleFilterChange(key, e.target.value)}
                                    disabled={isDisabled}
                                    className="w-full h-8 px-2 text-sm rounded-md bg-slate-800 border border-slate-700 text-slate-100 focus:outline-none focus:ring-1 focus:ring-indigo-500 disabled:opacity-50 disabled:cursor-not-allowed"
                                >
                                    <option value="">{isDisabled ? "Pick category" : "All"}</option>
                                    {options.map((opt) => (
                                        <option key={opt} value={opt}>{opt}</option>
                                    ))}
                                </select>
                            </div>
                        );
                    })}
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

            {/* Style — template + gender + persona dropdowns drive the user prompt */}
            <Card className="bg-slate-900 border-slate-800 p-4 space-y-3">
                <div className="flex items-center justify-between gap-2">
                    <Label className="text-xs text-slate-400">Style</Label>
                    <span className="text-[11px] text-slate-500">
                        Drives the variation notes below. Manual edits are kept until you Reset.
                    </span>
                </div>
                <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
                    {/* Template */}
                    <div className="space-y-1">
                        <Label className="text-xs text-slate-400">Template</Label>
                        {templates === null ? (
                            <Skeleton className="h-9 w-full bg-slate-800 rounded-md" />
                        ) : (
                            <select
                                value={templateId ?? ""}
                                onChange={(e) => setTemplateId(e.target.value || null)}
                                className="w-full h-9 px-2 text-sm rounded-md bg-slate-800 border border-slate-700 text-slate-100 focus:outline-none focus:ring-1 focus:ring-indigo-500"
                                disabled={templates.length === 0}
                            >
                                {templates.length === 0 && (
                                    <option value="">No templates</option>
                                )}
                                {templates.map((t) => (
                                    <option key={t.id} value={t.id}>{t.label}</option>
                                ))}
                            </select>
                        )}
                        {template?.description && (
                            <p className="text-[11px] text-slate-500 truncate">
                                {template.description}
                            </p>
                        )}
                    </div>

                    {/* Gender */}
                    <div className="space-y-1">
                        <Label className="text-xs text-slate-400">Gender</Label>
                        <select
                            value={gender}
                            onChange={(e) => setGender(e.target.value)}
                            className="w-full h-9 px-2 text-sm rounded-md bg-slate-800 border border-slate-700 text-slate-100 focus:outline-none focus:ring-1 focus:ring-indigo-500"
                        >
                            <option value="female">Female</option>
                            <option value="male">Male</option>
                        </select>
                        <p className="text-[11px] text-slate-500">
                            Filters which personas are available.
                        </p>
                    </div>

                    {/* Persona */}
                    <div className="space-y-1">
                        <Label className="text-xs text-slate-400">Persona</Label>
                        {visiblePersonas === null ? (
                            <Skeleton className="h-9 w-full bg-slate-800 rounded-md" />
                        ) : (
                            <select
                                value={personaId ?? ""}
                                onChange={(e) => setPersonaId(e.target.value || null)}
                                className="w-full h-9 px-2 text-sm rounded-md bg-slate-800 border border-slate-700 text-slate-100 focus:outline-none focus:ring-1 focus:ring-indigo-500"
                                disabled={visiblePersonas.length === 0}
                            >
                                {visiblePersonas.length === 0 && (
                                    <option value="">No personas</option>
                                )}
                                {visiblePersonas.map((p) => (
                                    <option key={p.id} value={p.id}>{p.label}</option>
                                ))}
                            </select>
                        )}
                        {persona && (
                            <p className="text-[11px] text-slate-500 line-clamp-2 whitespace-pre-line">
                                {persona.description.split("\n").slice(0, 2).join(" · ")}
                            </p>
                        )}
                    </div>
                </div>
            </Card>

            {/* System prompt — global default, editable for one-off tuning */}
            <Card className="bg-slate-900 border-slate-800 p-4 space-y-2">
                <div className="flex items-center justify-between gap-2">
                    <button
                        onClick={() => setSystemPromptOpen((v) => !v)}
                        className="flex items-center gap-2 text-sm text-slate-300 hover:text-white"
                        aria-expanded={systemPromptOpen}
                    >
                        {systemPromptOpen ? (
                            <ChevronUp className="w-4 h-4" />
                        ) : (
                            <ChevronDown className="w-4 h-4" />
                        )}
                        System prompt
                        <Badge
                            variant="outline"
                            className={
                                isSystemPromptDirty
                                    ? "border-amber-700 text-amber-400 text-[10px]"
                                    : "border-slate-700 text-slate-400 text-[10px]"
                            }
                        >
                            {isSystemPromptDirty ? "modified" : "global default"}
                        </Badge>
                    </button>
                    {isSystemPromptDirty && (
                        <Button
                            size="sm"
                            variant="outline"
                            onClick={resetSystemPrompt}
                            className="border-slate-700 text-slate-300 hover:bg-slate-800 h-7"
                        >
                            <RotateCcw className="w-3 h-3 mr-1" /> Reset
                        </Button>
                    )}
                </div>
                <p className="text-xs text-slate-500">
                    Style anchor sent on every generation. Keep it stable for consistent
                    output; edit it to retune the look across many runs.
                </p>
                {systemPromptOpen && (
                    <>
                        <Textarea
                            value={systemPrompt}
                            onChange={(e) => setSystemPrompt(e.target.value)}
                            rows={14}
                            spellCheck={false}
                            className="bg-slate-800 border-slate-700 text-slate-100 placeholder:text-slate-500 resize-y font-mono text-xs"
                        />
                        <p className="text-xs text-slate-500">
                            {systemPrompt.length} chars
                        </p>
                    </>
                )}
            </Card>

            {/* Variation notes — auto-composed from template + persona, hand-editable */}
            <Card className="bg-slate-900 border-slate-800 p-4 space-y-2">
                <div className="flex items-center justify-between gap-2">
                    <div className="flex items-center gap-2">
                        <Label className="text-xs text-slate-400">Variation notes</Label>
                        {composedUserPrompt.length > 0 && (
                            <Badge
                                variant="outline"
                                className={
                                    isUserPromptDirty
                                        ? "border-amber-700 text-amber-400 text-[10px]"
                                        : "border-slate-700 text-slate-400 text-[10px]"
                                }
                            >
                                {isUserPromptDirty ? "modified" : "from style"}
                            </Badge>
                        )}
                    </div>
                    {isUserPromptDirty && (
                        <Button
                            size="sm"
                            variant="outline"
                            onClick={resetUserPrompt}
                            className="border-slate-700 text-slate-300 hover:bg-slate-800 h-7"
                        >
                            <RotateCcw className="w-3 h-3 mr-1" /> Reset
                        </Button>
                    )}
                </div>
                <Textarea
                    value={prompt}
                    onChange={(e) => setPrompt(e.target.value)}
                    rows={6}
                    placeholder="Pick a template and persona above to auto-compose, or type your own variation notes."
                    className="bg-slate-800 border-slate-700 text-slate-100 placeholder:text-slate-500 resize-y"
                />
                <p className="text-xs text-slate-500">
                    Final prompt: {finalPrompt.length} / {PROMPT_CAP}
                    {finalPrompt.length > PROMPT_CAP && (
                        <span className="ml-2 text-red-400">over limit</span>
                    )}
                </p>
            </Card>

            {/* Final prompt preview — exact string sent to gpt-image-2 */}
            <Card className="bg-slate-900 border-slate-800 p-4 space-y-2">
                <div className="flex items-center justify-between gap-2">
                    <button
                        onClick={() => setPreviewOpen((v) => !v)}
                        className="flex items-center gap-2 text-sm text-slate-300 hover:text-white"
                        aria-expanded={previewOpen}
                    >
                        {previewOpen ? (
                            <ChevronUp className="w-4 h-4" />
                        ) : (
                            <ChevronDown className="w-4 h-4" />
                        )}
                        Final prompt preview
                        <Badge variant="outline" className="border-slate-700 text-slate-400 text-[10px]">
                            {finalPrompt.length} chars
                        </Badge>
                    </button>
                    {finalPrompt && (
                        <Button
                            size="sm"
                            variant="outline"
                            onClick={copyFinalPrompt}
                            className="border-slate-700 text-slate-300 hover:bg-slate-800 h-7"
                        >
                            <Copy className="w-3 h-3 mr-1" /> Copy
                        </Button>
                    )}
                </div>
                {previewOpen && (
                    <pre className="text-xs text-slate-300 whitespace-pre-wrap font-mono bg-slate-950 border border-slate-800 rounded-md p-3 max-h-96 overflow-auto">
                        {finalPrompt || "(empty — pick items and/or write a system prompt)"}
                    </pre>
                )}
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

            {/* Recent runs — persisted history scoped to the current user */}
            <Card className="bg-slate-900 border-slate-800 p-4 space-y-3">
                <div className="flex items-center justify-between gap-2">
                    <CardTitle className="text-sm font-medium text-slate-300 flex items-center gap-2">
                        <History className="w-4 h-4" />
                        Recent runs
                    </CardTitle>
                    <Button
                        size="sm"
                        variant="outline"
                        onClick={refreshRunsAfterGenerate}
                        disabled={runsLoading}
                        className="border-slate-700 text-slate-300 hover:bg-slate-800 h-7"
                    >
                        <RefreshCw className={`w-3 h-3 mr-1 ${runsLoading ? "animate-spin" : ""}`} />
                        Refresh
                    </Button>
                </div>

                {runs === null ? (
                    <div className="space-y-2">
                        {Array.from({ length: 3 }).map((_, i) => (
                            <Skeleton key={i} className="h-20 w-full bg-slate-800 rounded-md" />
                        ))}
                    </div>
                ) : runs.length === 0 ? (
                    <p className="text-xs text-slate-500 italic">
                        No runs yet. Generate something to see it here.
                    </p>
                ) : (
                    <ul className="divide-y divide-slate-800">
                        {runs.map((run) => {
                            const tplLabel =
                                templates?.find((t) => t.id === run.template_id)?.label;
                            const personaRow = allPersonas?.find((p) => p.id === run.persona_id);
                            const ts = TIMESTAMP_FMT.format(new Date(run.created_at));
                            const isFailed = run.status === "failed";
                            return (
                                <li key={run.id} className="flex gap-3 py-3 first:pt-0 last:pb-0">
                                    <div className="shrink-0 w-16 h-20 rounded border border-slate-700 bg-slate-800 overflow-hidden flex items-center justify-center">
                                        {run.images?.[0] ? (
                                            <img
                                                src={run.images[0]}
                                                alt={`Run ${run.id.slice(0, 8)}`}
                                                className="w-full h-full object-cover"
                                            />
                                        ) : (
                                            <ImageIcon className="w-5 h-5 text-slate-600" />
                                        )}
                                    </div>
                                    <div className="flex-1 min-w-0 space-y-1">
                                        <div className="flex items-center gap-2 text-xs">
                                            <Badge
                                                variant="outline"
                                                className={
                                                    isFailed
                                                        ? "border-red-800 text-red-400 text-[10px]"
                                                        : "border-emerald-800 text-emerald-400 text-[10px]"
                                                }
                                            >
                                                {run.status}
                                            </Badge>
                                            <span className="text-slate-400">{ts}</span>
                                            <span className="text-slate-600">·</span>
                                            <span className="text-slate-500">{run.size} · {run.quality} · n={run.n}</span>
                                        </div>
                                        {isFailed ? (
                                            <p className="text-xs text-red-300 truncate">
                                                {run.error_message || "Generation failed"}
                                            </p>
                                        ) : (
                                            <p className="text-xs text-slate-300 truncate">
                                                {excerpt(run.user_prompt_text) ||
                                                    excerpt(run.system_prompt_text)}
                                            </p>
                                        )}
                                        <p className="text-[11px] text-slate-500 truncate">
                                            {tplLabel ?? "—"}
                                            {personaRow && (
                                                <>
                                                    {" · "}
                                                    {personaRow.gender === "female" ? "F" : "M"}
                                                    {" · "}
                                                    {personaRow.label}
                                                </>
                                            )}
                                        </p>
                                    </div>
                                    <div className="shrink-0 flex flex-col gap-1">
                                        <Button
                                            size="sm"
                                            variant="outline"
                                            onClick={() => reproduceRun(run)}
                                            disabled={reproducing}
                                            className="border-slate-700 text-slate-300 hover:bg-slate-800 h-7 text-xs"
                                        >
                                            <RotateCcw className="w-3 h-3 mr-1" />
                                            Reproduce
                                        </Button>
                                        <Button
                                            size="sm"
                                            variant="outline"
                                            onClick={() => setViewingRunId(run.id)}
                                            className="border-slate-700 text-slate-300 hover:bg-slate-800 h-7 text-xs"
                                        >
                                            <Eye className="w-3 h-3 mr-1" />
                                            View
                                        </Button>
                                    </div>
                                </li>
                            );
                        })}
                    </ul>
                )}

                {runsCursor && (
                    <div className="pt-2">
                        <Button
                            size="sm"
                            variant="outline"
                            onClick={loadMoreRuns}
                            disabled={runsLoading}
                            className="border-slate-700 text-slate-300 hover:bg-slate-800 w-full"
                        >
                            {runsLoading ? (
                                <><Loader2 className="w-3 h-3 animate-spin mr-1" /> Loading…</>
                            ) : (
                                "Load more"
                            )}
                        </Button>
                    </div>
                )}
            </Card>

            {/* View full run modal — fetches fresh signed URLs each open */}
            <Dialog
                open={viewingRunId !== null}
                onOpenChange={(open) => {
                    if (!open) setViewingRunId(null);
                }}
            >
                <DialogContent className="bg-slate-900 border-slate-800 max-w-3xl max-h-[90vh] overflow-y-auto">
                    <DialogHeader>
                        <DialogTitle className="text-slate-100 flex items-center gap-2">
                            <Eye className="w-4 h-4" /> Run snapshot
                        </DialogTitle>
                        <DialogDescription className="text-slate-500 text-xs">
                            {viewingRunId && `Run ${viewingRunId.slice(0, 8)}`}
                            {viewingRun && (
                                <>
                                    {" · "}
                                    {TIMESTAMP_FMT.format(new Date(viewingRun.created_at))}
                                    {" · "}
                                    <span className={viewingRun.status === "failed" ? "text-red-400" : "text-emerald-400"}>
                                        {viewingRun.status}
                                    </span>
                                    {" · "}
                                    {viewingRun.size} · {viewingRun.quality} · n={viewingRun.n}
                                    {" · "}
                                    {viewingRun.elapsed_ms}ms
                                </>
                            )}
                        </DialogDescription>
                    </DialogHeader>

                    {viewingRunLoading || !viewingRun ? (
                        <div className="space-y-3">
                            <Skeleton className="h-24 w-full bg-slate-800" />
                            <Skeleton className="h-32 w-full bg-slate-800" />
                            <Skeleton className="h-32 w-full bg-slate-800" />
                        </div>
                    ) : (
                        <div className="space-y-4">
                            {viewingRun.images?.length > 0 && (
                                <div className="grid grid-cols-2 gap-2">
                                    {viewingRun.images.map((url, i) => (
                                        <a
                                            key={i}
                                            href={url}
                                            target="_blank"
                                            rel="noreferrer"
                                            className="block rounded border border-slate-700 overflow-hidden hover:border-slate-500"
                                        >
                                            <img src={url} alt={`Image ${i + 1}`} className="w-full" />
                                        </a>
                                    ))}
                                </div>
                            )}
                            {viewingRun.error_message && (
                                <Alert variant="destructive" className="bg-red-950 border-red-800">
                                    <AlertCircle className="h-4 w-4" />
                                    <AlertDescription>{viewingRun.error_message}</AlertDescription>
                                </Alert>
                            )}
                            <div className="space-y-1">
                                <Label className="text-xs text-slate-400">System prompt</Label>
                                <pre className="text-xs text-slate-300 whitespace-pre-wrap font-mono bg-slate-950 border border-slate-800 rounded-md p-3 max-h-48 overflow-auto">
                                    {viewingRun.system_prompt_text}
                                </pre>
                            </div>
                            <div className="space-y-1">
                                <Label className="text-xs text-slate-400">User prompt</Label>
                                <pre className="text-xs text-slate-300 whitespace-pre-wrap font-mono bg-slate-950 border border-slate-800 rounded-md p-3 max-h-48 overflow-auto">
                                    {viewingRun.user_prompt_text || "(empty)"}
                                </pre>
                            </div>
                            <div className="flex justify-end gap-2 pt-2">
                                <Button
                                    size="sm"
                                    variant="outline"
                                    onClick={() => {
                                        const r = viewingRun;
                                        setViewingRunId(null);
                                        reproduceRun(r);
                                    }}
                                    disabled={reproducing}
                                    className="border-slate-700 text-slate-300 hover:bg-slate-800"
                                >
                                    <RotateCcw className="w-3 h-3 mr-1" /> Reproduce
                                </Button>
                            </div>
                        </div>
                    )}
                </DialogContent>
            </Dialog>
        </div>
    );
}
