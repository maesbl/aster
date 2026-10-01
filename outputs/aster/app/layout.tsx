import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Aster — Your personal companion",
  description: "A private space to think, create, and find your next step with Aster.",
  icons: {
    icon: "/favicon.svg",
    shortcut: "/favicon.svg",
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body className="antialiased">{children}</body>
    </html>
  );
}
