"use client";

import { createContext, useContext, useEffect, useState } from "react";
import { useRouter, usePathname } from "next/navigation";
import { getMe } from "@/lib/api";

const AuthContext = createContext(null);

export function AuthProvider({ children }) {
    const [user, setUser] = useState(null);
    const [token, setToken] = useState(null);
    const [loading, setLoading] = useState(true);
    const router = useRouter();
    const pathname = usePathname();

    useEffect(() => {
        const stored = localStorage.getItem("outfitter_token");
        if (stored) {
            setToken(stored);
            getMe()
                .then(setUser)
                .catch(() => {
                    localStorage.removeItem("outfitter_token");
                    setToken(null);
                })
                .finally(() => setLoading(false));
        } else {
            setLoading(false);
        }
    }, []);

    useEffect(() => {
        if (!loading && !token && pathname !== "/login") {
            router.push("/login");
        }
    }, [loading, token, pathname, router]);

    function storeLogin(accessToken, userData) {
        localStorage.setItem("outfitter_token", accessToken);
        setToken(accessToken);
        setUser(userData);
    }

    function logout() {
        localStorage.removeItem("outfitter_token");
        setToken(null);
        setUser(null);
        router.push("/login");
    }

    return (
        <AuthContext.Provider value={{ user, token, loading, storeLogin, logout, isAuthenticated: !!token }}>
            {children}
        </AuthContext.Provider>
    );
}

export function useAuth() {
    const ctx = useContext(AuthContext);
    if (!ctx) throw new Error("useAuth must be used inside AuthProvider");
    return ctx;
}
