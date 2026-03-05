import { Inter } from "next/font/google";
import "./globals.css";
import { AuthProvider } from "@/lib/auth";
import Sidebar from "@/components/Sidebar";
import Header from "@/components/Header";
import { Toaster } from "@/components/ui/sonner";

const inter = Inter({ subsets: ["latin"] });

export const metadata = {
  title: "Outfitter Admin",
  description: "Admin panel for the Outfitter backend API",
};

export default function RootLayout({ children }) {
  return (
    <html lang="en" className="dark">
      <body className={`${inter.className} bg-slate-950 text-slate-100 antialiased`}>
        <AuthProvider>
          <LayoutShell>{children}</LayoutShell>
        </AuthProvider>
        <Toaster theme="dark" richColors />
      </body>
    </html>
  );
}

function LayoutShell({ children }) {
  return <AuthLayoutBridge>{children}</AuthLayoutBridge>;
}

// Client component handles nav visibility
import AuthLayoutBridge from "@/components/AuthLayoutBridge";
