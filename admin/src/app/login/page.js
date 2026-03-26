"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { useAuth } from "@/lib/auth";
import { login, getMe } from "@/lib/api";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Alert, AlertDescription } from "@/components/ui/alert";
import { Shirt, AlertCircle, Loader2 } from "lucide-react";

export default function LoginPage() {
    const [email, setEmail] = useState("");
    const [password, setPassword] = useState("");
    const [error, setError] = useState("");
    const [loading, setLoading] = useState(false);
    const { storeLogin } = useAuth();
    const router = useRouter();

    async function handleSubmit(e) {
        e.preventDefault();
        setError("");
        setLoading(true);
        try {
            const normalizedEmail = email.trim().toLowerCase();
            const { access_token } = await login(normalizedEmail, password);
            // Store token BEFORE getMe so apiFetch can attach Bearer header
            localStorage.setItem("outfitter_token", access_token);
            const user = await getMe();
            storeLogin(access_token, user);
            router.push("/");
        } catch (err) {
            setError(err.message || "Login failed");
        } finally {
            setLoading(false);
        }
    }

    return (
        <div className="min-h-screen bg-slate-950 flex items-center justify-center p-4">
            <div className="w-full max-w-md">
                <div className="flex justify-center mb-8">
                    <div className="flex items-center gap-3">
                        <div className="w-10 h-10 rounded-xl bg-indigo-600 flex items-center justify-center shadow-lg shadow-indigo-900/50">
                            <Shirt className="w-5 h-5 text-white" />
                        </div>
                        <div>
                            <h1 className="text-xl font-bold text-white">Outfitter</h1>
                            <p className="text-xs text-slate-400">Admin Panel</p>
                        </div>
                    </div>
                </div>

                <Card className="bg-slate-900 border-slate-800 shadow-xl">
                    <CardHeader className="space-y-1">
                        <CardTitle className="text-white text-2xl">Sign in</CardTitle>
                        <CardDescription className="text-slate-400">
                            Enter your credentials to access the admin panel
                        </CardDescription>
                    </CardHeader>
                    <CardContent>
                        <form onSubmit={handleSubmit} className="space-y-4">
                            {error && (
                                <Alert variant="destructive" className="bg-red-950 border-red-800">
                                    <AlertCircle className="h-4 w-4" />
                                    <AlertDescription>{error}</AlertDescription>
                                </Alert>
                            )}
                            <div className="space-y-2">
                                <Label htmlFor="email" className="text-slate-300">Email</Label>
                                <Input
                                    id="email"
                                    type="email"
                                    placeholder="user@example.com"
                                    value={email}
                                    onChange={(e) => setEmail(e.target.value)}
                                    required
                                    className="bg-slate-800 border-slate-700 text-slate-100 placeholder:text-slate-500 focus:border-indigo-500"
                                />
                            </div>
                            <div className="space-y-2">
                                <Label htmlFor="password" className="text-slate-300">Password</Label>
                                <Input
                                    id="password"
                                    type="password"
                                    placeholder="••••••••"
                                    value={password}
                                    onChange={(e) => setPassword(e.target.value)}
                                    required
                                    className="bg-slate-800 border-slate-700 text-slate-100 placeholder:text-slate-500 focus:border-indigo-500"
                                />
                            </div>
                            <Button
                                type="submit"
                                className="w-full bg-indigo-600 hover:bg-indigo-700 text-white"
                                disabled={loading}
                            >
                                {loading ? <><Loader2 className="w-4 h-4 animate-spin mr-2" />Signing in...</> : "Sign in"}
                            </Button>
                        </form>
                    </CardContent>
                </Card>
            </div>
        </div>
    );
}
