"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { useAuth } from "@/lib/auth";
import { healthCheck, searchCatalog, listWardrobe, listOutfits } from "@/lib/api";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Skeleton } from "@/components/ui/skeleton";
import { Search, Shirt, Layers, Camera, User, Activity, Database } from "lucide-react";

function StatCard({ title, value, icon: Icon, href, loading }) {
  return (
    <Link href={href}>
      <Card className="bg-slate-900 border-slate-800 hover:border-indigo-700 transition-colors cursor-pointer group">
        <CardHeader className="flex flex-row items-center justify-between pb-2">
          <CardTitle className="text-sm font-medium text-slate-400">{title}</CardTitle>
          <Icon className="w-4 h-4 text-slate-500 group-hover:text-indigo-400 transition-colors" />
        </CardHeader>
        <CardContent>
          {loading ? (
            <Skeleton className="h-8 w-16 bg-slate-800" />
          ) : (
            <p className="text-3xl font-bold text-white">{value ?? "—"}</p>
          )}
        </CardContent>
      </Card>
    </Link>
  );
}

export default function DashboardPage() {
  const { user } = useAuth();
  const [health, setHealth] = useState(null);
  const [stats, setStats] = useState({});
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    Promise.all([
      healthCheck().catch(() => null),
      searchCatalog({ limit: 1 }).catch(() => null),
      listWardrobe({ limit: 1 }).catch(() => null),
      listOutfits().catch(() => null),
    ]).then(([h, catalog, wardrobe, outfits]) => {
      setHealth(h);
      setStats({
        catalog: catalog?.total ?? "—",
        wardrobe: wardrobe?.total ?? "—",
        outfits: outfits?.items?.length ?? "—",
      });
      setLoading(false);
    });
  }, []);

  return (
    <div className="space-y-8">
      {/* Page header */}
      <div>
        <h1 className="text-2xl font-bold text-white">Dashboard</h1>
        <p className="text-slate-400 mt-1">Overview of the Outfitter backend</p>
      </div>

      {/* Health + User info cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        <Card className="bg-slate-900 border-slate-800">
          <CardHeader className="flex flex-row items-center gap-3 pb-2">
            <Activity className="w-4 h-4 text-slate-400" />
            <CardTitle className="text-sm font-medium text-slate-400">Backend Health</CardTitle>
          </CardHeader>
          <CardContent className="space-y-2">
            {health ? (
              <>
                <Badge className="bg-emerald-600 hover:bg-emerald-600">
                  ● {health.status}
                </Badge>
                <p className="text-xs text-slate-500">Environment: <span className="text-slate-300">{health.env}</span></p>
              </>
            ) : (
              <Badge variant="destructive">● Offline</Badge>
            )}
          </CardContent>
        </Card>

        <Card className="bg-slate-900 border-slate-800">
          <CardHeader className="flex flex-row items-center gap-3 pb-2">
            <User className="w-4 h-4 text-slate-400" />
            <CardTitle className="text-sm font-medium text-slate-400">Current User</CardTitle>
          </CardHeader>
          <CardContent className="space-y-1">
            {user ? (
              <>
                <p className="text-white font-medium">{user.email}</p>
                <p className="text-xs text-slate-500 font-mono">{user.id}</p>
                <p className="text-xs text-slate-500">
                  Joined: {new Date(user.created_at).toLocaleDateString()}
                  {user.skin_tone && <> · Skin tone: {user.skin_tone}</>}
                </p>
              </>
            ) : (
              <Skeleton className="h-4 w-48 bg-slate-800" />
            )}
          </CardContent>
        </Card>
      </div>

      {/* Stats */}
      <div>
        <div className="flex items-center gap-2 mb-4">
          <Database className="w-4 h-4 text-slate-400" />
          <h2 className="text-sm font-medium text-slate-400 uppercase tracking-wide">Data Stats</h2>
        </div>
        <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
          <StatCard title="Catalog Items" value={stats.catalog} icon={Search} href="/catalog" loading={loading} />
          <StatCard title="Wardrobe Items" value={stats.wardrobe} icon={Shirt} href="/wardrobe" loading={loading} />
          <StatCard title="Saved Outfits" value={stats.outfits} icon={Layers} href="/outfits" loading={loading} />
        </div>
      </div>

      {/* Quick links */}
      <div>
        <h2 className="text-sm font-medium text-slate-400 uppercase tracking-wide mb-4">Quick Access</h2>
        <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
          {[
            { label: "Search Catalog", href: "/catalog", icon: Search, color: "text-blue-400" },
            { label: "Manage Wardrobe", href: "/wardrobe", icon: Shirt, color: "text-violet-400" },
            { label: "View Outfits", href: "/outfits", icon: Layers, color: "text-pink-400" },
            { label: "Try-On Studio", href: "/tryon", icon: Camera, color: "text-amber-400" },
          ].map(({ label, href, icon: Icon, color }) => (
            <Link key={href} href={href}>
              <Card className="bg-slate-900 border-slate-800 hover:border-slate-600 transition-colors cursor-pointer p-4 flex flex-col items-center gap-2 text-center">
                <Icon className={`w-6 h-6 ${color}`} />
                <span className="text-xs text-slate-300 font-medium">{label}</span>
              </Card>
            </Link>
          ))}
        </div>
      </div>
    </div>
  );
}
