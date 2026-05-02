import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const title = process.argv[2];

if (!title) {
  console.error('❌ 请提供文章标题，例如: npm run post "我的新文章"');
  process.exit(1);
}

const date = new Date();
const year = date.getFullYear();
const month = String(date.getMonth() + 1).padStart(2, '0');
const day = String(date.getDate()).padStart(2, '0');
const hours = String(date.getHours()).padStart(2, '0');
const minutes = String(date.getMinutes()).padStart(2, '0');

// 简单的 slug 转换（保留中文、英文、数字，空格转连字符）
const slug = title
  .toLowerCase()
  .replace(/\s+/g, '-')
  .replace(/[^\w\u4e00-\u9fa5-]/g, '');

const filename = `${year}-${month}-${day}-${slug}.md`;
const filepath = path.join(__dirname, '..', 'src', 'content', 'blog', filename);

const frontmatter = `---
title: ${title}
date: ${year}-${month}-${day} ${hours}:${minutes} +0800
categories: 
---

`;

fs.writeFileSync(filepath, frontmatter);
console.log(`✅ 成功创建文章: src/content/blog/${filename}`);
