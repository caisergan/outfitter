"use client";

import { useState, useRef, useCallback } from "react";
import { submitTryOn, getTryOnStatus } from "@/lib/api";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Textarea } from "@/components/ui/textarea";
import { Alert, AlertDescription } from "@/components/ui/alert";
import { Loader2, Camera, RefreshCw, AlertCircle, CheckCircle2 } from "lucide-react";
import { toast } from "sonner";

const STATUS_COLORS = {
    pending: "bg-amber-700",
    processing: "bg-blue-700",
    complete: "bg-emerald-700",
    failed: "bg-red-700",
};

export default function TryOnPage() {
    // Submit state
    const [submitForm, setSubmitForm] = useState({ slots: "{}", model_preference: "neutral", user_photo_url: "" });
    const [submitLoading, setSubmitLoading] = useState(false);
    const [lastJobId, setLastJobId] = useState("");

    // Status state
    const [jobId, setJobId] = useState("");
    const [statusResult, setStatusResult] = useState(null);
    const [polling, setPolling] = useState(false);
    const pollRef = useRef(null);

    async function handleSubmit(e) {
        e.preventDefault();
        setSubmitLoading(true);
        try {
            let slots;
            try { slots = JSON.parse(submitForm.slots); } catch { toast.error("Invalid JSON in slots"); setSubmitLoading(false); return; }
            const data = await submitTryOn({
                slots,
                model_preference: submitForm.model_preference,
                ...(submitForm.user_photo_url && { user_photo_url: submitForm.user_photo_url }),
            });
            setLastJobId(data.job_id);
            setJobId(data.job_id);
            toast.success(`Job submitted: ${data.job_id}`);
        } catch (err) {
            toast.error(err.message);
        } finally {
            setSubmitLoading(false);
        }
    }

    const stopPolling = useCallback(() => {
        if (pollRef.current) {
            clearInterval(pollRef.current);
            pollRef.current = null;
        }
        setPolling(false);
    }, []);

    async function checkStatus(id) {
        try {
            const data = await getTryOnStatus(id);
            setStatusResult(data);
            if (data.status === "complete" || data.status === "failed") {
                stopPolling();
                if (data.status === "complete") toast.success("Try-on complete!");
                else toast.error(`Try-on failed: ${data.error || "unknown error"}`);
            }
        } catch (err) {
            toast.error(err.message);
            stopPolling();
        }
    }

    function startPolling() {
        const targetId = jobId.trim();
        if (!targetId) { toast.error("Enter a job ID"); return; }
        setStatusResult(null);
        setPolling(true);
        checkStatus(targetId);
        pollRef.current = setInterval(() => checkStatus(targetId), 3000);
    }

    return (
        <div className="space-y-6">
            <div>
                <h1 className="text-2xl font-bold text-white">Try-On Studio</h1>
                <p className="text-slate-400 mt-1">Submit virtual try-on jobs and track their status</p>
            </div>

            <Tabs defaultValue="submit">
                <TabsList className="bg-slate-800 border-slate-700">
                    <TabsTrigger value="submit" className="data-[state=active]:bg-indigo-600 data-[state=active]:text-white">Submit Job</TabsTrigger>
                    <TabsTrigger value="status" className="data-[state=active]:bg-indigo-600 data-[state=active]:text-white">Track Status</TabsTrigger>
                </TabsList>

                {/* Submit tab */}
                <TabsContent value="submit" className="mt-4">
                    <Card className="bg-slate-900 border-slate-800">
                        <CardHeader>
                            <CardTitle className="text-white text-base flex items-center gap-2">
                                <Camera className="w-4 h-4 text-indigo-400" />
                                Submit Try-On Request
                            </CardTitle>
                            <p className="text-slate-400 text-sm">Rate-limited: max 10 requests per minute per user</p>
                        </CardHeader>
                        <CardContent>
                            <form onSubmit={handleSubmit} className="space-y-4">
                                <div className="space-y-1">
                                    <Label className="text-xs text-slate-400">Slots (JSON) *</Label>
                                    <Textarea
                                        value={submitForm.slots}
                                        onChange={(e) => setSubmitForm({ ...submitForm, slots: e.target.value })}
                                        rows={6}
                                        placeholder={'{\n  "top": "item-uuid-here",\n  "bottom": "item-uuid-here"\n}'}
                                        className="bg-slate-800 border-slate-700 text-slate-100 placeholder:text-slate-500 text-sm font-mono resize-none"
                                    />
                                    <p className="text-xs text-slate-500">Map slot names (top, bottom, shoes, accessory, outerwear, bag) to item UUIDs</p>
                                </div>
                                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                                    <div className="space-y-1">
                                        <Label className="text-xs text-slate-400">Model Preference</Label>
                                        <Input
                                            placeholder="neutral"
                                            value={submitForm.model_preference}
                                            onChange={(e) => setSubmitForm({ ...submitForm, model_preference: e.target.value })}
                                            className="bg-slate-800 border-slate-700 text-slate-100 placeholder:text-slate-500 text-sm"
                                        />
                                    </div>
                                    <div className="space-y-1">
                                        <Label className="text-xs text-slate-400">User Photo URL (optional)</Label>
                                        <Input
                                            placeholder="https://..."
                                            value={submitForm.user_photo_url}
                                            onChange={(e) => setSubmitForm({ ...submitForm, user_photo_url: e.target.value })}
                                            className="bg-slate-800 border-slate-700 text-slate-100 placeholder:text-slate-500 text-sm"
                                        />
                                    </div>
                                </div>
                                <Button type="submit" disabled={submitLoading} className="bg-indigo-600 hover:bg-indigo-700">
                                    {submitLoading ? <><Loader2 className="w-4 h-4 animate-spin mr-2" />Submitting...</> : "Submit Job"}
                                </Button>
                            </form>

                            {lastJobId && (
                                <Alert className="mt-4 bg-slate-800 border-slate-700">
                                    <AlertDescription className="text-slate-300">
                                        Job submitted! ID: <span className="font-mono text-indigo-300 select-all">{lastJobId}</span>
                                        <br />
                                        <span className="text-xs text-slate-500">Switch to "Track Status" tab to monitor.</span>
                                    </AlertDescription>
                                </Alert>
                            )}
                        </CardContent>
                    </Card>
                </TabsContent>

                {/* Status tab */}
                <TabsContent value="status" className="mt-4">
                    <Card className="bg-slate-900 border-slate-800">
                        <CardHeader>
                            <CardTitle className="text-white text-base flex items-center gap-2">
                                <RefreshCw className="w-4 h-4 text-indigo-400" />
                                Track Job Status
                            </CardTitle>
                            <p className="text-slate-400 text-sm">Polls every 3 seconds until complete or failed</p>
                        </CardHeader>
                        <CardContent className="space-y-4">
                            <div className="flex gap-2">
                                <Input
                                    placeholder="Enter job ID"
                                    value={jobId}
                                    onChange={(e) => setJobId(e.target.value)}
                                    className="bg-slate-800 border-slate-700 text-slate-100 placeholder:text-slate-500 font-mono text-sm"
                                />
                                {!polling ? (
                                    <Button onClick={startPolling} className="bg-indigo-600 hover:bg-indigo-700 shrink-0">
                                        Start Polling
                                    </Button>
                                ) : (
                                    <Button onClick={stopPolling} variant="outline" className="border-slate-600 text-slate-300 hover:bg-slate-800 shrink-0">
                                        <Loader2 className="w-4 h-4 animate-spin mr-2" />Stop
                                    </Button>
                                )}
                            </div>

                            {statusResult && (
                                <div className="space-y-4">
                                    <div className="flex items-center gap-3">
                                        <Badge className={STATUS_COLORS[statusResult.status] || "bg-slate-700"}>
                                            {statusResult.status}
                                        </Badge>
                                        <span className="text-xs font-mono text-slate-500">{statusResult.job_id}</span>
                                    </div>

                                    {statusResult.status === "complete" && statusResult.image_url && (
                                        <div className="space-y-2">
                                            <p className="text-xs text-slate-400 flex items-center gap-1">
                                                <CheckCircle2 className="w-3 h-3 text-emerald-400" />
                                                Try-on result:
                                            </p>
                                            <img
                                                src={statusResult.image_url}
                                                alt="Try-on result"
                                                className="max-w-sm rounded-lg border border-slate-700 shadow-lg"
                                            />
                                            <p className="text-xs">
                                                <a href={statusResult.image_url} target="_blank" rel="noreferrer"
                                                    className="text-indigo-400 hover:text-indigo-300 underline">
                                                    Open in new tab ↗
                                                </a>
                                            </p>
                                        </div>
                                    )}

                                    {statusResult.status === "failed" && (
                                        <Alert variant="destructive" className="bg-red-950 border-red-800">
                                            <AlertCircle className="h-4 w-4" />
                                            <AlertDescription>{statusResult.error || "Unknown error"}</AlertDescription>
                                        </Alert>
                                    )}

                                    {(statusResult.status === "pending" || statusResult.status === "processing") && polling && (
                                        <div className="flex items-center gap-2 text-slate-400 text-sm">
                                            <Loader2 className="w-4 h-4 animate-spin text-indigo-400" />
                                            Job in progress, polling every 3 seconds…
                                        </div>
                                    )}
                                </div>
                            )}
                        </CardContent>
                    </Card>
                </TabsContent>
            </Tabs>
        </div>
    );
}
