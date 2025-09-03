# Sinan 书签管理扩展

一个功能强大的 Chrome 书签同步与管理扩展，提供智能搜索、omnibox 快速访问、暗黑模式和云端同步功能。

## ✨ 核心功能

### 🔍 Omnibox 快速搜索
在浏览器地址栏输入 `bm` + 空格，即可实时搜索所有书签：
- **实时搜索建议**：输入关键词即时显示匹配的书签
- **多种打开方式**：支持当前标签页、新标签页打开
- **最多10个结果**：精准匹配，避免信息过载

### 🏠 新标签页替换
全新设计的新标签页，替代浏览器默认页面：
- **智能推荐**：基于访问频率显示最常用书签
- **实时搜索**：搜索框支持书签名称、网址、描述模糊查找
- **响应式布局**：自动适配屏幕尺寸，动态调整显示数量
- **快捷操作**：
  - 左键：当前标签页打开
  - Ctrl/Cmd+左键：新标签页后台打开
  - 中键：新标签页后台打开

### 🔧 扩展管理面板
点击扩展图标的弹窗管理界面：
- **服务器配置**：设置 Sinan 服务器地址和 API 密钥
- **自动同步**：可配置 1/5/10/15/30 分钟同步间隔
- **手动操作**：立即同步、删除书签目录、打开主页
- **同步状态**：显示最后同步时间和操作结果

### 🌙 主题系统
- **暗黑模式**：支持明暗主题切换
- **系统跟随**：自动检测系统主题偏好
- **持久保存**：主题设置自动保存

### ☁️ 云端同步
- **自动上传**：新建书签自动同步到服务器
- **定时同步**：从服务器拉取最新书签数据
- **智能过滤**：自动排除 Sinan 文件夹，避免重复同步
- **使用统计**：记录书签访问次数，优化推荐算法

## 📁 项目结构

```
sinan-chrome-extension-v2/
├── src/
│   ├── manifest.json           # Chrome 扩展清单文件 (包含 omnibox 配置)
│   ├── style.css              # 全局样式和主题变量
│   ├── background/
│   │   └── service-worker.js  # 后台脚本 (同步逻辑 + omnibox 事件)
│   ├── shared/                # 共享服务和类型
│   │   ├── services/
│   │   │   ├── api.ts         # API 服务层
│   │   │   ├── storage.ts     # 本地存储服务
│   │   │   └── bookmark.ts    # 书签操作服务
│   │   └── types/
│   │       └── api.ts         # API 类型定义
│   ├── components/            # UI 组件库
│   │   └── ui/
│   │       ├── button/        # 按钮组件
│   │       ├── input/         # 输入框组件
│   │       ├── switch/        # 开关组件
│   │       ├── select/        # 选择器组件
│   │       ├── form/          # 表单组件
│   │       └── alert/         # 提示组件
│   ├── lib/
│   │   └── utils.ts          # 工具函数
│   ├── popup/                # 扩展设置弹窗
│   │   ├── index.html
│   │   └── src/
│   │       ├── App.vue        # 配置管理界面
│   │       └── main.ts
│   ├── option/               # 选项页面
│   │   ├── index.html
│   │   └── src/
│   │       ├── App.vue
│   │       └── main.ts
│   └── newtab/               # 新标签页
│       ├── index.html
│       └── src/
│           ├── App.vue        # 书签展示和搜索界面
│           └── main.ts
├── dist/                     # 构建输出目录
├── vite.config.ts           # Vite 配置
├── tsconfig.json            # TypeScript 配置
└── package.json
```

## 🎯 使用方法

### Omnibox 快速搜索
1. 在浏览器地址栏输入 `bm` 然后按空格
2. 输入书签关键词（名称、网址等）
3. 从下拉建议中选择书签或直接回车打开第一个匹配项

### 新标签页使用
1. 打开新标签页自动显示常用书签
2. 使用顶部搜索框快速查找书签
3. 点击右上角按钮切换主题、刷新数据或访问主页

### 扩展管理
1. 点击扩展图标打开设置面板
2. 配置服务器地址和 API 密钥
3. 开启自动同步并设置合适的间隔时间

## 🚀 安装使用

### 开发环境
- Node.js >= 16
- pnpm (推荐) 或 npm

### 构建安装
```bash
# 克隆项目
git clone <your-repo-url>
cd sinan-chrome-extension-v2

# 安装依赖
pnpm install

# 构建扩展
pnpm build

# 安装到 Chrome
# 1. 打开 chrome://extensions/
# 2. 开启"开发者模式"
# 3. 点击"加载已解压的扩展程序"
# 4. 选择 dist 目录
```

### 开发调试
```bash
# 启动开发服务器
pnpm dev

# 访问调试页面：
# - Popup: http://localhost:5173/src/popup/index.html
# - NewTab: http://localhost:5173/src/newtab/index.html
# - Options: http://localhost:5173/src/option/index.html
```

## 🛠️ 技术栈

- **框架**: Vue 3 + TypeScript
- **构建**: Vite 7.x
- **样式**: Tailwind CSS 4.x
- **组件**: shadcn-vue (基于 Reka UI)
- **表单**: vee-validate + zod
- **工具**: @vueuse/core
- **扩展**: Chrome Manifest V3

## 🔧 主要特性

### 智能书签推荐
- 基于访问频率的智能排序
- 星标书签优先显示
- 自动记录使用统计

### 多种访问方式
- **Omnibox**: 地址栏输入 `bm` 快速搜索
- **新标签页**: 替换默认新标签页显示常用书签
- **扩展面板**: 配置和管理同步设置

### 云端数据同步
- 支持私有 Sinan 服务器
- 自动/手动同步模式
- 增量同步避免重复数据

### 现代化界面
- 响应式设计适配各种屏幕
- 明暗主题自动切换
- shadcn-vue 组件库统一视觉

## ⚙️ 配置说明

### Manifest 配置
```json
{
  "manifest_version": 3,
  "name": "Sinan书签管理器-BATE",
  "permissions": ["storage", "tabs", "bookmarks", "alarms"],
  "omnibox": { "keyword": "bm" },
  "chrome_url_overrides": { "newtab": "src/newtab/index.html" },
  "background": { "service_worker": "background/service-worker.js" }
}
```

### 权限说明
- **storage**: 保存扩展配置
- **tabs**: 打开和管理标签页
- **bookmarks**: 读写浏览器书签
- **alarms**: 定时同步功能
- **host_permissions**: 访问任意网站（用于 API 请求）

## 🔧 开发说明

### 添加 shadcn-vue 组件
```bash
# 添加新组件
pnpm dlx shadcn-vue@latest add dialog card avatar

# 查看可用组件
pnpm dlx shadcn-vue@latest add
```

### 主题定制
在 `src/style.css` 中修改 CSS 变量来定制主题色彩：
```css
:root {
  --primary: 222.2 84% 4.9%;
  --secondary: 210 40% 96%;
  /* 更多主题变量... */
}
```

## ⚠️ 常见问题

### Omnibox 不显示建议
- 确认已重新加载扩展
- 检查是否正确输入 `bm` + 空格
- 查看扩展控制台是否有错误

### 同步失败
- 检查服务器地址和 API 密钥
- 确认网络连接正常
- 查看后台脚本日志

### 新标签页无书签
- 首次使用需要先配置并同步
- 尝试手动刷新
- 检查是否有书签数据

## 📄 许可证

MIT License

---

**立即体验地址栏 `bm` 快速搜索功能！**
