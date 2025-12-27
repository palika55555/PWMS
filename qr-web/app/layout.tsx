import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "PWMS – QR skener paliet",
  description: "Jednoduché skenovanie QR kódov paliet (príjem/výdaj) a prehľad zásob."
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="sk">
      <body>{children}</body>
    </html>
  );
}


