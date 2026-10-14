// import z from "zod"
// import z from "zod"
import { z } from "https://esm.sh/zod@3.22.1";

export const SitemapItems = z.object({
  id: z.string().nullable().optional(),
  type: z.string().nullable().optional(),
  url: z.string().nullable().optional(),
  lastmod: z
    .union([z.string(), z.date(), z.null()])
    .nullable()
    .optional(), // optional allows it to be undefined
  changefreq: z
    .enum(["always", "hourly", "daily", "weekly", "monthly", "yearly", "never"])
    .nullable()
    .optional(),
  priority: z
    .string()
    .regex(/^0(\.\d+)?|1(\.0+)?$/, "Priority must be between 0.0 and 1.0")
    .nullable()
    .optional(),
}).strict();

export const SitemapEntries = z.object({
  url: z.array(SitemapItems).nullable().optional(),
}).strict();
