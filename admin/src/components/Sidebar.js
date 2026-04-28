"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import {
    LayoutDashboard,
    Search,
    Shirt,
    Layers,
    Camera,
    Sparkles,
} from "lucide-react";
import { cn } from "@/lib/utils";

const navItems = [
    { href: "/", label: "Dashboard", icon: LayoutDashboard },
    { href: "/catalog", label: "Catalog", icon: Search },
    { href: "/wardrobe", label: "Wardrobe", icon: Shirt },
    { href: "/outfits", label: "Outfits", icon: Layers },
    { href: "/tryon", label: "Try-On", icon: Camera },
    { href: "/playground", label: "Playground", icon: Sparkles },
];

export default function Sidebar() {
    const pathname = usePathname();

    return (
        <aside className="w-64 bg-slate-900 border-r border-slate-800 min-h-screen flex flex-col">
            <div className="p-6 border-b border-slate-800">
                <div className="flex items-center gap-2">
                    <div className="w-8 h-8 rounded-lg bg-indigo-600 flex items-center justify-center">
                        <Shirt className="w-4 h-4 text-white" />
                    </div>
                    <span className="font-semibold text-white text-lg">Outfitter</span>
                    <span className="text-xs text-slate-400 ml-1">Admin</span>
                </div>
            </div>

            <nav className="flex-1 p-4 space-y-1">
                {navItems.map(({ href, label, icon: Icon }) => {
                    const active = pathname === href;
                    return (
                        <Link
                            key={href}
                            href={href}
                            className={cn(
                                "flex items-center gap-3 px-3 py-2.5 rounded-md text-sm font-medium transition-colors",
                                active
                                    ? "bg-indigo-600 text-white"
                                    : "text-slate-400 hover:bg-slate-800 hover:text-slate-100"
                            )}
                        >
                            <Icon className="w-4 h-4 flex-shrink-0" />
                            {label}
                        </Link>
                    );
                })}
            </nav>

            <div className="p-4 border-t border-slate-800">
                <p className="text-xs text-slate-500">Outfitter Admin Panel</p>
            </div>
        </aside>
    );
}
