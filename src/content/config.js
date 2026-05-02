import { defineCollection, z } from 'astro:content';

const blog = defineCollection({
  type: 'content',
  schema: z.object({
    title: z.string().optional(),
    date: z.coerce.date().optional(),
    categories: z.string().optional(),
    category: z.string().optional(),
  }),
});

export const collections = { blog };
