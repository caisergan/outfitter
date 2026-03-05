"use client";

import { useAuth } from "@/lib/auth";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import {
    DropdownMenu,
    DropdownMenuContent,
    DropdownMenuItem,
    DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { ChevronDown, User, LogOut } from "lucide-react";
import { useEffect, useState } from "react";
import { healthCheck } from "@/lib/api";

export default function Header() {
    const { user, logout } = useAuth();
    const [healthy, setHealthy] = useState(null);

    useEffect(() => {
        healthCheck()
            .then((d) => setHealthy(d?.status === "ok"))
            .catch(() => setHealthy(false));
    }, []);

    return (
        <header className="h-14 bg-slate-900 border-b border-slate-800 flex items-center justify-between px-6">
            <div className="flex items-center gap-3">
                {healthy !== null && (
                    <Badge
                        variant={healthy ? "default" : "destructive"}
                        className={healthy ? "bg-emerald-600 hover:bg-emerald-600" : ""}
                    >
                        <span className="w-1.5 h-1.5 rounded-full bg-current mr-1.5 inline-block" />
                        {healthy ? "Backend Online" : "Backend Offline"}
                    </Badge>
                )}
            </div>

            <DropdownMenu>
                <DropdownMenuTrigger asChild>
                    <Button variant="ghost" size="sm" className="text-slate-300 hover:text-white hover:bg-slate-800 gap-2">
                        <User className="w-4 h-4" />
                        <span className="text-sm">{user?.email ?? "Loading..."}</span>
                        <ChevronDown className="w-3 h-3" />
                    </Button>
                </DropdownMenuTrigger>
                <DropdownMenuContent align="end" className="bg-slate-900 border-slate-700 text-slate-200">
                    <DropdownMenuItem className="text-xs text-slate-500 cursor-default focus:bg-transparent">
                        {user?.id}
                    </DropdownMenuItem>
                    <DropdownMenuItem
                        onClick={logout}
                        className="text-red-400 focus:text-red-400 focus:bg-red-950 cursor-pointer"
                    >
                        <LogOut className="w-3.5 h-3.5 mr-2" />
                        Logout
                    </DropdownMenuItem>
                </DropdownMenuContent>
            </DropdownMenu>
        </header>
    );
}
