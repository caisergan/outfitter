"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { getMe } from "@/lib/api";
import { Card } from "@/components/ui/card";
import { Loader2, ShieldOff, Settings, FileText, Users } from "lucide-react";
import { cn } from "@/lib/utils";

const ADMIN_NAV = [
    { href: "/admin/system-prompt", label: "System prompt", icon: FileText },
    { href: "/admin/templates", label: "Templates", icon: Settings },
    { href: "/admin/personas", label: "Personas", icon: Users },
];

export default function AdminLayout({ children }) {
    const pathname = usePathname();
    const [state, setState] = useState({ kind: "loading" });

    useEffect(() => {
        getMe()
            .then((user) =>
                setState({
                    kind: user?.role === "admin" ? "ok" : "denied",
                    user,
                }),
            )
            .catch((err) =>
                setState({ kind: "denied", error: err.message ?? "Unknown error" }),
            );
    }, []);

    if (state.kind === "loading") {
        return (
            <div className="flex items-center gap-2 text-slate-400 p-6">
                <Loader2 className="w-4 h-4 animate-spin" />
                <span>Checking permissions…</span>
            </div>
        );
    }

    if (state.kind === "denied") {
        return (
            <Card className="bg-slate-900 border-slate-800 p-6 max-w-xl">
                <div className="flex items-start gap-3">
                    <ShieldOff className="w-5 h-5 text-red-400 mt-0.5 shrink-0" />
                    <div className="space-y-2">
                        <h2 className="text-lg font-semibold text-white">
                            Admin access required
                        </h2>
                        <p className="text-sm text-slate-400">
                            This section is restricted to admin users. If this is your
                            account and you should have access, ask the database owner to
                            promote your role:
                        </p>
                        <pre className="text-xs text-slate-300 bg-slate-950 border border-slate-800 rounded p-2 font-mono">
                            UPDATE users SET role = 'admin' WHERE email = '...';
                        </pre>
                        <Link
                            href="/tryon"
                            className="text-xs text-indigo-400 hover:text-indigo-300 underline"
                        >
                            Back to try-on
                        </Link>
                    </div>
                </div>
            </Card>
        );
    }

    return (
        <div className="space-y-4">
            <nav className="flex gap-1 border-b border-slate-800 pb-2">
                {ADMIN_NAV.map(({ href, label, icon: Icon }) => {
                    const active = pathname === href;
                    return (
                        <Link
                            key={href}
                            href={href}
                            className={cn(
                                "flex items-center gap-2 px-3 py-2 rounded-md text-sm font-medium transition-colors",
                                active
                                    ? "bg-slate-800 text-white"
                                    : "text-slate-400 hover:bg-slate-800 hover:text-slate-100",
                            )}
                        >
                            <Icon className="w-4 h-4" />
                            {label}
                        </Link>
                    );
                })}
            </nav>
            {children}
        </div>
    );
}
