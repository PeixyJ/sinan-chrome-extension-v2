<script setup lang="ts">
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import Textarea from "@/components/ui/textarea/Textarea.vue";
import { Alert, AlertDescription } from "@/components/ui/alert";
import Skeleton from "@/components/ui/skeleton/Skeleton.vue";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { onMounted, ref, computed, watch } from 'vue'
import { SinanApiService } from '../../shared/services/api'
import { IconService } from '../../shared/services/icon'
import { IconCacheService } from '../../shared/services/iconCache'
import { BookmarkCacheService } from '../../shared/services/bookmarkCache'
import { StorageService } from '../../shared/services/storage'
import { NewtabBackgroundService } from '../../shared/services/tagBackground'
import type { BookmarkResp, SnSpace } from '../../shared/types/api'

const bookmarks = ref<BookmarkResp[]>([])
const searchQuery = ref('')

// 书签选中状态管理 - 矩阵导航
const selectedRow = ref(-1) // -1 表示在搜索框
const selectedCol = ref(0) // 列索引
const isKeyboardNavigation = ref(false) // 标记是否在使用键盘导航

// 默认搜索引擎书签
const defaultSearchEngines = ref<BookmarkResp[]>([
  {
    id: 'search-baidu',
    namespaceId: 'default',
    name: '{query} For Baidu',
    description: '百度一下，你就知道',
    url: 'https://www.baidu.com',
    icon: '',
    num: 0,
    star: false,
    tags: [],
    searchUrl: 'https://www.baidu.com/s?wd={query}'  // 使用占位符
  },
  {
    id: 'search-google',
    namespaceId: 'default',
    name: '{query} For Google',
    description: 'Google 搜索引擎',
    url: 'https://www.google.com',
    icon: '',
    num: 0,
    star: false,
    tags: [],
    searchUrl: 'https://www.google.com/search?q={query}'
  },
  {
    id: 'search-bing',
    namespaceId: 'default',
    name: '{query} For Bing',
    description: 'Microsoft Bing 搜索引擎',
    url: 'https://www.bing.com',
    icon: '',
    num: 0,
    star: false,
    tags: [],
    searchUrl: 'https://www.bing.com/search?q={query}'
  },
  {
    id: 'search-github',
    namespaceId: 'default',
    name: '{query} For GitHub',
    description: '在GitHub上搜索代码和项目',
    url: 'https://github.com',
    icon: '',
    num: 0,
    star: false,
    tags: [],
    searchUrl: 'https://github.com/search?q={query}'
  },
  {
    id: 'search-stackoverflow',
    namespaceId: 'default',
    name: '{query} For Stack Overflow',
    description: '程序员问答社区',
    url: 'https://stackoverflow.com',
    icon: '',
    num: 0,
    star: false,
    tags: [],
    searchUrl: 'https://stackoverflow.com/search?q={query}'
  },
  {
    id: 'search-bilibili',
    namespaceId: 'default',
    name: '{query} For Bilibili',
    description: '在哔哩哔哩搜索视频',
    url: 'https://search.bilibili.com',
    icon: '',
    num: 0,
    star: false,
    tags: [],
    searchUrl: 'https://search.bilibili.com/all?keyword={query}'
  },
  {
    id: 'search-dockerhub',
    namespaceId: 'default',
    name: '{query} For Docker Hub',
    description: '搜索Docker镜像',
    url: 'https://hub.docker.com',
    icon: '',
    num: 0,
    star: false,
    tags: [],
    searchUrl: 'https://hub.docker.com/search?q={query}&type=image'
  },
  {
    id: 'search-taobao',
    namespaceId: 'default',
    name: '{query} For Taobao',
    description: '在淘宝搜索商品',
    url: 'https://www.taobao.com',
    icon: '',
    num: 0,
    star: false,
    tags: [],
    searchUrl: 'https://s.taobao.com/search?q={query}'
  },
  {
    id: 'search-steam',
    namespaceId: 'default',
    name: '{query} For Steam',
    description: '在Steam搜索游戏',
    url: 'https://store.steampowered.com',
    icon: '',
    num: 0,
    star: false,
    tags: [],
    searchUrl: 'https://store.steampowered.com/search/?snr=1_4_4__12&term={query}'
  },
  {
    id: 'search-unsplash',
    namespaceId: 'default',
    name: '{query} For Unsplash',
    description: '搜索高质量免费图片',
    url: 'https://unsplash.com',
    icon: '',
    num: 0,
    star: false,
    tags: [],
    searchUrl: 'https://unsplash.com/s/photos/{query}'
  },
  {
    id: 'search-youtube',
    namespaceId: 'default',
    name: '{query} For YouTube',
    description: '在YouTube搜索视频',
    url: 'https://www.youtube.com',
    icon: '',
    num: 0,
    star: false,
    tags: [],
    searchUrl: 'https://www.youtube.com/results?search_query={query}'
  },
  {
    id: 'search-wikipedia',
    namespaceId: 'default',
    name: '{query} For Wikipedia',
    description: '在维基百科搜索条目',
    url: 'https://zh.wikipedia.org',
    icon: '',
    num: 0,
    star: false,
    tags: [],
    searchUrl: 'https://zh.wikipedia.org/wiki/{query}'
  }
] as (BookmarkResp & { searchUrl: string })[])
const isLoading = ref(true)
const isRefreshing = ref(false)
const isSearching = ref(false)
const searchDebounceTimer = ref<number>()
const errorAlert = ref<{ show: boolean; message: string }>({
  show: false,
  message: ''
})

// 暗黑模式状态
const isDarkMode = ref(false)

// Newtab背景配置
const backgroundConfig = ref({
  enabled: true,
  source: 'blank' as 'local' | 'blank' | 'bing' | 'urls',
  image: '',
  urls: '' as string,
  blurEnabled: true,
  blurIntensity: 10
})

// 背景图片URL
const backgroundImageUrl = ref('')

// 用于直接CSS背景的URL（不需要base64转换）
const backgroundDirectUrl = ref('')

// 服务地址配置
const webUrl = ref('https://sinan.host')

// 欢迎词配置
const welcomeConfig = ref({
  title: 'Welcome to Sinan',
  subtitle: "Let's hurry to our destination."
})

// 加载当前配置的背景
const loadBackgroundConfig = async () => {
  console.log('=== Loading Background Config ===')
  try {
    const config = await StorageService.getConfig()
    backgroundConfig.value = {
      enabled: config.newtabBackgroundEnabled,
      source: config.newtabBackgroundSource,
      image: config.newtabBackgroundImage || '',
      urls: config.newtabBackgroundUrls || '[]',
      blurEnabled: config.newtabBlurEnabled,
      blurIntensity: config.newtabBlurIntensity
    }

    // 设置服务地址
    webUrl.value = config.webUrl || 'https://sinan.host'

    // 设置欢迎词
    welcomeConfig.value = {
      title: config.welcomeTitle || 'Welcome to Sinan',
      subtitle: config.welcomeSubtitle || "Let's hurry to our destination."
    }

    // 根据背景来源加载背景图片
    console.log('Loading background, source:', backgroundConfig.value.source)

    if (backgroundConfig.value.source === 'local' && backgroundConfig.value.image) {
      console.log('Using local image:', backgroundConfig.value.image)
      backgroundImageUrl.value = backgroundConfig.value.image
      backgroundDirectUrl.value = ''
    } else if (backgroundConfig.value.source === 'urls') {
      try {
        const randomUrl = await NewtabBackgroundService.getCurrentBackgroundImageUrl(config)
        if (randomUrl) {
          console.log('Using random URL image:', randomUrl)
          backgroundDirectUrl.value = randomUrl
          backgroundImageUrl.value = ''
        } else {
          console.log('No valid URLs available')
        }
      } catch (error) {
        console.error('加载随机URL图片失败:', error)
      }
    } else if (backgroundConfig.value.source === 'bing') {
      try {
        const bingUrl = await NewtabBackgroundService.getBingDailyImage()
        console.log('Using Bing image:', bingUrl)
        backgroundImageUrl.value = bingUrl
        backgroundDirectUrl.value = ''
      } catch (error) {
        console.error('加载Bing图片失败:', error)
      }
    } else {
      console.log('No background image to load')
    }
  } catch (error) {
    console.error('加载背景配置失败:', error)
  }
}

// 获取背景样式
const backgroundStyle = computed(() => {
  console.log('Computing background style:')
  console.log('  source:', backgroundConfig.value.source)
  console.log('  backgroundImageUrl:', backgroundImageUrl.value)
  console.log('  backgroundDirectUrl:', backgroundDirectUrl.value)

  if (backgroundConfig.value.source === 'blank' || (!backgroundImageUrl.value && !backgroundDirectUrl.value)) {
    console.log('No background image, returning empty style')
    return {}
  }

  const imageUrl = backgroundImageUrl.value || backgroundDirectUrl.value
  console.log('Using image URL:', imageUrl)

  const style: any = {
    backgroundImage: `url(${imageUrl})`,
    backgroundSize: 'cover',
    backgroundPosition: 'center',
    backgroundRepeat: 'no-repeat',
    backgroundAttachment: 'fixed'
  }

  console.log('Background style:', style)
  return style
})

// 获取毛玻璃样式
const backdropStyle = computed(() => {
  if (backgroundConfig.value.source === 'blank' || backgroundConfig.value.blurIntensity === 0) {
    return {}
  }

  return {
    backdropFilter: `blur(${backgroundConfig.value.blurIntensity}px)`,
    WebkitBackdropFilter: `blur(${backgroundConfig.value.blurIntensity}px)`,
    backgroundColor: 'rgba(255, 255, 255, 0.1)'
  }
})

// 新增书签对话框状态
const showAddBookmarkDialog = ref(false)
const newBookmark = ref({
  name: '',
  url: '',
  description: '',
  namespaceId: ''
})

// namespace相关状态
const namespaces = ref<SnSpace[]>([])
const isLoadingNamespaces = ref(false)

// 计算屏幕可显示的书签数量
const calculateBookmarksLimit = () => {
  const screenWidth = window.innerWidth
  const screenHeight = window.innerHeight

  // 减去页面边距和其他元素的高度
  const pageMargin = 64  // p-8 = 32px * 2
  const titleHeight = 100  // "Welcome back!" 标题和描述区域
  const searchBoxHeight = 88  // 搜索框 + mb-8 间距
  const errorAlertHeight = errorAlert.value.show ? 60 : 0  // 错误提示高度
  const availableHeight = screenHeight - pageMargin - titleHeight - searchBoxHeight - errorAlertHeight

  // 书签卡片尺寸
  const cardHeight = 62 + 16  // h-[62px] + gap-4
  const cardMinWidth = 300 + 16  // minmax(300px) + gap-4

  // 计算每行可放置的卡片数量
  const cardsPerRow = Math.floor((screenWidth - pageMargin) / cardMinWidth)

  // 计算可显示的行数
  const rowsCount = Math.floor(availableHeight / cardHeight)

  // 总书签数量，至少20个，最多200个
  const totalBookmarks = Math.max(20, Math.min(200, cardsPerRow * rowsCount))

  console.log(`屏幕尺寸: ${screenWidth}x${screenHeight}`)
  console.log(`可用高度: ${availableHeight}px (减去标题${titleHeight}px, 搜索框${searchBoxHeight}px, 边距${pageMargin}px)`)
  console.log(`每行卡片数: ${cardsPerRow}, 行数: ${rowsCount}`)
  console.log(`计算的书签数量: ${totalBookmarks}`)

  return totalBookmarks
}

// 计算网格布局信息
const calculateGridLayout = () => {
  const screenWidth = window.innerWidth
  const pageMargin = 64  // p-8 = 32px * 2
  const cardMinWidth = 300 + 16  // minmax(300px) + gap-4

  // 计算每行可放置的卡片数量
  const columnsPerRow = Math.floor((screenWidth - pageMargin) / cardMinWidth)

  return {
    columnsPerRow: Math.max(1, columnsPerRow) // 至少1列
  }
}

// 获取当前网格布局信息
const gridLayout = computed(() => calculateGridLayout())

// 根据行列获取书签索引
const getBookmarkIndex = (row: number, col: number): number => {
  return row * gridLayout.value.columnsPerRow + col
}

// 根据书签索引获取行列
const getRowCol = (index: number): { row: number, col: number } => {
  const row = Math.floor(index / gridLayout.value.columnsPerRow)
  const col = index % gridLayout.value.columnsPerRow
  return { row, col }
}

// 获取当前选中的书签索引
const selectedBookmarkIndex = computed(() => {
  if (selectedRow.value === -1) return -1
  return getBookmarkIndex(selectedRow.value, selectedCol.value)
})

// 搜索书签的函数
const searchBookmarks = async (query: string) => {
  try {
    isSearching.value = true
    errorAlert.value.show = false

    let response
    if (query.trim()) {
      // 有搜索关键词时调用搜索接口
      response = await SinanApiService.searchBookmarks(query.trim())
    } else {
      // 无搜索关键词时获取最常访问的书签
      const limit = calculateBookmarksLimit()
      response = await SinanApiService.getMostVisitedBookmarks({ limit })
    }

    if (response.code === 0) {
      bookmarks.value = response.data
      console.log('搜索完成:', response.data.length, '个书签')
      
      // 如果是获取最常访问的书签（无搜索关键词），保存到缓存
      if (!query.trim()) {
        const limit = calculateBookmarksLimit()
        await BookmarkCacheService.saveBookmarksToCache(response.data, limit)
      }
      
      // 异步加载书签图标，不阻塞UI
      preloadFaviconsAsync(response.data)
    } else if (response.code === -1) {
      errorAlert.value = {
        show: true,
        message: response.message
      }
      console.error('搜索API返回错误:', response.message)
    }
  } catch (error) {
    console.error('搜索时出错:', error)
    errorAlert.value = {
      show: true,
      message: `搜索失败: ${error instanceof Error ? error.message : String(error)}`
    }
  } finally {
    isSearching.value = false
  }
}

// 防抖搜索
const debouncedSearch = (query: string) => {
  if (searchDebounceTimer.value) {
    clearTimeout(searchDebounceTimer.value)
  }
  
  searchDebounceTimer.value = setTimeout(() => {
    searchBookmarks(query)
  }, 300) // 300ms 防抖
}

const filteredBookmarks = computed(() => {
  // 如果有搜索查询
  if (searchQuery.value.trim()) {
    // 如果搜索有结果，只返回搜索结果
    if (bookmarks.value.length > 0) {
      return bookmarks.value
    } else {
      // 如果搜索无结果，显示搜索引擎（让用户可以用关键词搜索）
      return defaultSearchEngines.value
    }
  }

  // 如果没有搜索查询，只显示书签，不显示搜索引擎
  return bookmarks.value
})

// 获取显示名称，替换 {query} 为实际搜索内容
const getDisplayName = (bookmark: BookmarkResp) => {
  if (searchQuery.value.trim() && bookmark.name.includes('{query}')) {
    return bookmark.name.replace('{query}', searchQuery.value.trim())
  }
  // 如果没有搜索查询但名称包含{query}，则只显示平台名称
  if (bookmark.name.includes('{query}')) {
    return bookmark.name.replace('{query} For ', '')
  }
  return bookmark.name
}

// 从缓存加载书签
const loadBookmarksFromCache = async (limit: number) => {
  try {
    const cachedBookmarks = await BookmarkCacheService.getCachedBookmarks(limit)
    if (cachedBookmarks && cachedBookmarks.length > 0) {
      bookmarks.value = cachedBookmarks
      console.log('从缓存加载书签成功:', cachedBookmarks.length, '个书签')
      
      // 异步加载缓存书签的图标
      preloadFaviconsAsync(cachedBookmarks)
      
      // 设置加载完成，显示缓存内容
      isLoading.value = false
      return true
    }
    return false
  } catch (error) {
    console.error('加载缓存书签失败:', error)
    return false
  }
}

const loadMostVisitedBookmarks = async (useCache = true) => {
  try {
    errorAlert.value.show = false

    // 动态计算需要的书签数量
    const limit = calculateBookmarksLimit()
    
    // 首先尝试从缓存加载（如果启用）
    if (useCache) {
      const cacheLoaded = await loadBookmarksFromCache(limit)
      // 如果缓存加载成功，继续在后台获取最新数据
      if (cacheLoaded) {
        console.log('缓存加载成功，后台获取最新数据...')
      }
    }

    // 获取最新的书签数据
    const response = await SinanApiService.getMostVisitedBookmarks({ limit })

    if (response.code === 0) {
      bookmarks.value = response.data
      console.log('加载最常访问书签成功:', response.data.length, '个书签')
      
      // 保存到缓存
      await BookmarkCacheService.saveBookmarksToCache(response.data, limit)
      
      // 异步加载书签图标，不阻塞UI
      preloadFaviconsAsync(response.data)
    } else if (response.code === -1) {
      errorAlert.value = {
        show: true,
        message: response.message
      }
      console.error('API返回错误:', response.message)
    } else {
      console.error('加载最常访问书签失败:', response.message)
    }
  } catch (error) {
    console.error('加载书签时出错:', error)
    
    // 如果没有使用缓存且出错，尝试使用缓存
    if (useCache && bookmarks.value.length === 0) {
      const limit = calculateBookmarksLimit()
      const cacheLoaded = await loadBookmarksFromCache(limit)
      if (cacheLoaded) {
        console.log('网络请求失败，使用缓存数据')
      } else {
        errorAlert.value = {
          show: true,
          message: `网络请求失败: ${error instanceof Error ? error.message : String(error)}`
        }
      }
    } else if (!useCache) {
      errorAlert.value = {
        show: true,
        message: `网络请求失败: ${error instanceof Error ? error.message : String(error)}`
      }
    }
  } finally {
    isLoading.value = false
    isRefreshing.value = false
  }
}

const handleBookmarkClick = async (bookmark: BookmarkResp, event: MouseEvent) => {
  // 阻止默认行为
  event.preventDefault()

  console.log('点击事件详情:', {
    button: event.button,
    ctrlKey: event.ctrlKey,
    metaKey: event.metaKey,
    bookmark: bookmark.name
  })

  // 检查是否是搜索引擎书签
  const searchEngine = bookmark as BookmarkResp & { searchUrl?: string }
  let targetUrl = bookmark.url

  // 如果是搜索引擎且有搜索查询，构造搜索URL
  if (searchEngine.searchUrl && searchQuery.value.trim()) {
    targetUrl = searchEngine.searchUrl.replace('{query}', encodeURIComponent(searchQuery.value.trim()))
    console.log('使用搜索URL:', targetUrl)
  }

  // 只有非搜索引擎书签才调用API
  if (!bookmark.id.startsWith('search-')) {
    try {
      // 调用increment-usage接口
      const response = await SinanApiService.incrementBookmarkUsage(bookmark.id)

      if (response.code === 0) {
        console.log('书签使用次数已增加:', bookmark.name)
      } else if (response.code === -1) {
        console.error('增加使用次数API错误:', response.message)
        errorAlert.value = {
          show: true,
          message: `更新使用次数失败: ${response.message}`
        }
        // 3秒后自动隐藏错误提示
        setTimeout(() => {
          errorAlert.value.show = false
        }, 3000)
      }
    } catch (error) {
      console.error('增加书签使用次数失败:', error)
    }
  }

  // 根据点击方式打开书签
  if (event.button === 1 || event.ctrlKey || event.metaKey) {
    // 鼠标中键、Ctrl+点击、Cmd+点击：在新标签页打开但不跳转
    console.log('在后台标签页打开书签:', targetUrl)
    if (typeof chrome !== 'undefined' && chrome.tabs) {
      chrome.tabs.create({ url: targetUrl, active: false })
    } else {
      // 开发环境fallback
      window.open(targetUrl, '_blank')
    }
  } else {
    // 鼠标左键：在当前标签页打开
    console.log('在当前标签页打开书签:', targetUrl)
    window.location.href = targetUrl
  }
}

const handleMouseDown = (bookmark: BookmarkResp, event: MouseEvent) => {
  // 只处理鼠标中键
  if (event.button === 1) {
    event.preventDefault()
    // 直接处理中键点击，避免与click事件冲突
    incrementUsageAndOpenBackground(bookmark)
  }
}

const incrementUsageAndOpenBackground = async (bookmark: BookmarkResp) => {
  try {
    // 调用increment-usage接口
    const response = await SinanApiService.incrementBookmarkUsage(bookmark.id)

    if (response.code === 0) {
      console.log('书签使用次数已增加:', bookmark.name)
    } else if (response.code === -1) {
      console.error('增加使用次数API错误:', response.message)
      errorAlert.value = {
        show: true,
        message: `更新使用次数失败: ${response.message}`
      }
      setTimeout(() => {
        errorAlert.value.show = false
      }, 3000)
    }
  } catch (error) {
    console.error('增加书签使用次数失败:', error)
  }

  // 在后台标签页打开
  console.log('在后台标签页打开书签:', bookmark.url)
  if (typeof chrome !== 'undefined' && chrome.tabs) {
    chrome.tabs.create({ url: bookmark.url, active: false })
  } else {
    window.open(bookmark.url, '_blank')
  }
}

const handleRefresh = async () => {
  if (isRefreshing.value) return
  isRefreshing.value = true
  // 刷新时不使用缓存，强制从服务器获取最新数据
  await loadMostVisitedBookmarks(false)
}

const openSinanHomepage = () => {
  const sinanUrl = webUrl.value
  if (typeof chrome !== 'undefined' && chrome.tabs) {
    chrome.tabs.create({ url: sinanUrl, active: true })
  } else {
    window.open(sinanUrl, '_blank')
  }
}

// 打开新增书签对话框
const openAddBookmarkDialog = async () => {
  showAddBookmarkDialog.value = true
  await loadNamespaces()
  
  // 尝试读取剪切板内容
  try {
    if (navigator.clipboard && navigator.clipboard.readText) {
      const clipboardText = await navigator.clipboard.readText()
      const trimmedText = clipboardText.trim()
      
      // 检查剪切板内容是否是有效的URL
      if (trimmedText && (trimmedText.startsWith('http://') || trimmedText.startsWith('https://') || trimmedText.startsWith('www.'))) {
        // 如果是www开头，自动添加https://
        const url = trimmedText.startsWith('www.') ? `https://${trimmedText}` : trimmedText
        newBookmark.value.url = url
        console.log('从剪切板获取URL:', url)
        
        // 自动获取网页标题
        setTimeout(() => {
          fetchTitleFromUrl()
        }, 100) // 延迟一点执行，确保URL已经设置
      }
    }
  } catch (error) {
    console.log('读取剪切板失败:', error)
    // 忽略剪切板读取错误，不影响用户体验
  }
}

// 关闭新增书签对话框
const closeAddBookmarkDialog = () => {
  showAddBookmarkDialog.value = false
  // 重置表单
  newBookmark.value = {
    name: '',
    url: '',
    description: '',
    namespaceId: ''
  }
}

// 获取网址标题和描述
const fetchTitleFromUrl = async () => {
  const url = newBookmark.value.url.trim()
  
  // 如果URL为空，则不自动获取
  if (!url) {
    return
  }
  
  try {
    // 验证URL格式
    const urlObject = new URL(url.startsWith('http') ? url : `https://${url}`)
    
    // 发起请求获取页面内容
    const response = await fetch(urlObject.toString(), {
      method: 'GET',
      mode: 'cors',
    })
    
    if (response.ok) {
      const html = await response.text()
      
      // 只有在书签名称为空时才自动获取标题
      if (!newBookmark.value.name.trim()) {
        const titleMatch = html.match(/<title[^>]*>([^<]+)<\/title>/i)
        if (titleMatch && titleMatch[1]) {
          const title = titleMatch[1].trim()
          if (title) {
            newBookmark.value.name = title
            console.log('自动获取网页标题:', title)
          }
        }
      }
      
      // 只有在描述为空时才自动获取描述
      if (!newBookmark.value.description.trim()) {
        // 尝试获取多种description meta标签
        const descriptionPatterns = [
          /<meta\s+name=["\']description["\']\s+content=["\']([^"\']*)["\'][^>]*>/i,
          /<meta\s+content=["\']([^"\']*)["\'][^>]*\s+name=["\']description["\']/i,
          /<meta\s+property=["\']og:description["\']\s+content=["\']([^"\']*)["\'][^>]*>/i,
          /<meta\s+name=["\']twitter:description["\']\s+content=["\']([^"\']*)["\'][^>]*>/i
        ]
        
        for (const pattern of descriptionPatterns) {
          const descMatch = html.match(pattern)
          if (descMatch && descMatch[1]) {
            const description = descMatch[1].trim()
            if (description && description.length > 10) { // 确保描述有意义
              newBookmark.value.description = description
              console.log('自动获取网页描述:', description)
              break
            }
          }
        }
      }
    }
  } catch (error) {
    console.log('获取网页信息失败:', error)
    // 如果获取失败，尝试使用URL的域名作为名称（仅在名称为空时）
    if (!newBookmark.value.name.trim()) {
      try {
        const urlObject = new URL(url.startsWith('http') ? url : `https://${url}`)
        const hostname = urlObject.hostname.replace('www.', '')
        newBookmark.value.name = hostname
        console.log('使用域名作为书签名称:', hostname)
      } catch (urlError) {
        console.log('URL解析失败:', urlError)
      }
    }
  }
}

// 获取所有namespace
const loadNamespaces = async () => {
  if (isLoadingNamespaces.value) return
  
  isLoadingNamespaces.value = true
  try {
    const response = await SinanApiService.getSpaces()
    if (response.code === 0) {
      namespaces.value = response.data
      console.log('加载namespace成功:', response.data.length, '个空间')
      
      // 如果没有选中的namespace，默认选择第一个
      if (namespaces.value.length > 0 && !newBookmark.value.namespaceId) {
        newBookmark.value.namespaceId = namespaces.value[0].id
      }
    } else {
      console.error('获取namespace列表失败:', response.message)
      errorAlert.value = {
        show: true,
        message: `获取空间列表失败: ${response.message}`
      }
      setTimeout(() => {
        errorAlert.value.show = false
      }, 3000)
    }
  } catch (error) {
    console.error('获取namespace列表时出错:', error)
    errorAlert.value = {
      show: true,
      message: `获取空间列表失败: ${error instanceof Error ? error.message : String(error)}`
    }
    setTimeout(() => {
      errorAlert.value.show = false
    }, 3000)
  } finally {
    isLoadingNamespaces.value = false
  }
}

// 添加书签
const addBookmark = async () => {
  if (!newBookmark.value.name.trim() || !newBookmark.value.url.trim()) {
    errorAlert.value = {
      show: true,
      message: '书签名称和网址不能为空'
    }
    setTimeout(() => {
      errorAlert.value.show = false
    }, 3000)
    return
  }

  try {
    const response = await SinanApiService.addBookmark({
      name: newBookmark.value.name.trim(),
      url: newBookmark.value.url.trim(),
      description: newBookmark.value.description.trim() || undefined,
      namespaceId: newBookmark.value.namespaceId || undefined
    })

    if (response.code === 0) {
      console.log('书签添加成功:', response.data)
      closeAddBookmarkDialog()
      // 刷新书签列表
      await loadMostVisitedBookmarks(false)
    } else {
      errorAlert.value = {
        show: true,
        message: `添加书签失败: ${response.message}`
      }
      setTimeout(() => {
        errorAlert.value.show = false
      }, 3000)
    }
  } catch (error) {
    console.error('添加书签失败:', error)
    errorAlert.value = {
      show: true,
      message: `添加书签失败: ${error instanceof Error ? error.message : String(error)}`
    }
    setTimeout(() => {
      errorAlert.value.show = false
    }, 3000)
  }
}


// 默认图标 - 使用扩展的图标
const DEFAULT_ICON = '/icon48.png'

// 缓存图标URL
const faviconCache = ref<Map<string, string>>(new Map())
// 跟踪正在加载的图标
const loadingFavicons = ref<Set<string>>(new Set())

// 异步加载图标，不阻塞UI
const loadFaviconAsync = async (url: string) => {
  if (faviconCache.value.has(url) || loadingFavicons.value.has(url)) {
    return
  }
  
  loadingFavicons.value.add(url)
  
  try {
    console.log('[Newtab] 开始加载图标:', url)
    const faviconUrl = await IconService.getFavicon(url)
    console.log('[Newtab] 获取到图标URL:', faviconUrl)
    faviconCache.value.set(url, faviconUrl)
    
    // 保存到持久化缓存
    await IconCacheService.saveIconToCache(url, faviconUrl)
  } catch (error) {
    console.warn('Failed to load favicon for', url, error)
    // 设置默认图标
    faviconCache.value.set(url, DEFAULT_ICON)
    // 也保存默认图标到缓存
    await IconCacheService.saveIconToCache(url, DEFAULT_ICON)
  } finally {
    loadingFavicons.value.delete(url)
  }
}

// 获取缓存的图标URL，如果没有缓存则返回默认图标
const getCachedFavicon = (url: string): string => {
  return faviconCache.value.get(url) || DEFAULT_ICON
}

// 检查图标是否正在加载
const isFaviconLoading = (url: string): boolean => {
  return loadingFavicons.value.has(url)
}

// 判断图标是否为base64格式
// 判断是否为有效的图标（HTTP URL 或 base64）
const isValidIcon = (icon: number | string): boolean => {
  console.log('实际链接为：', icon)
  if (typeof icon !== 'string') return false
  // 检查是否为 HTTP/HTTPS URL
  if (icon.startsWith('http://') || icon.startsWith('https://')) return true
  // 检查是否为 base64 图片
  if (icon.startsWith('data:image/')) return true
  return false
}

// 检查图标是否已加载
const isFaviconLoaded = (url: string): boolean => {
  return faviconCache.value.has(url)
}

// 从持久化缓存加载图标
const loadCachedIcons = async () => {
  try {
    console.log('加载缓存的图标...')
    const cachedIcons = await IconCacheService.getCachedIcons()
    
    // 将缓存的图标添加到内存缓存
    cachedIcons.forEach((faviconUrl, url) => {
      faviconCache.value.set(url, faviconUrl)
    })
    
    console.log(`成功加载 ${cachedIcons.size} 个缓存图标`)
  } catch (error) {
    console.error('加载缓存图标失败:', error)
  }
}

// 异步加载书签图标，不阻塞UI
const preloadFaviconsAsync = (bookmarkList: BookmarkResp[]) => {
  bookmarkList.forEach((bookmark) => {
    loadFaviconAsync(bookmark.url)
  })
  
  // 可选：等待所有图标加载完成后批量保存到缓存
  // 这样可以减少频繁的存储操作
  Promise.all(
    bookmarkList.map(bookmark => loadFaviconAsync(bookmark.url))
  ).then(() => {
    // 批量保存当前缓存状态
    saveCacheState()
  }).catch(error => {
    console.warn('Some icons failed to load:', error)
    // 即使有失败的，也保存成功加载的
    saveCacheState()
  })
}

// 保存当前缓存状态
const saveCacheState = async () => {
  try {
    if (faviconCache.value.size > 0) {
      await IconCacheService.saveBatchToCache(faviconCache.value)
    }
  } catch (error) {
    console.error('保存图标缓存失败:', error)
  }
}

// 确保当书签显示时图标开始加载
const ensureFaviconLoading = (url: string) => {
  if (!isFaviconLoaded(url) && !isFaviconLoading(url)) {
    loadFaviconAsync(url)
  }
}

// 切换暗黑模式
const toggleDarkMode = () => {
  isDarkMode.value = !isDarkMode.value
  if (isDarkMode.value) {
    document.documentElement.classList.add('dark')
  } else {
    document.documentElement.classList.remove('dark')
  }
  // 保存到本地存储
  localStorage.setItem('darkMode', isDarkMode.value.toString())
}

onMounted(async () => {
  // 加载背景配置
  await loadBackgroundConfig()

  // 从本地存储读取暗黑模式设置
  const savedDarkMode = localStorage.getItem('darkMode')
  if (savedDarkMode === 'true') {
    isDarkMode.value = true
    document.documentElement.classList.add('dark')
  } else if (savedDarkMode === 'false') {
    isDarkMode.value = false
    document.documentElement.classList.remove('dark')
  } else {
    // 如果没有保存的设置，使用系统偏好
    const prefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches
    isDarkMode.value = prefersDark
    if (prefersDark) {
      document.documentElement.classList.add('dark')
    }
  }

  // 首先加载缓存的图标
  await loadCachedIcons()

  // 然后加载最常访问的书签
  loadMostVisitedBookmarks()

  // 监听窗口大小变化，重新计算书签数量
  let resizeTimeout: number
  const handleResize = () => {
    clearTimeout(resizeTimeout)
    resizeTimeout = setTimeout(() => {
      if (!isLoading.value && !isRefreshing.value) {
        loadMostVisitedBookmarks()
      }
    }, 300) // 防抖300ms
  }

  window.addEventListener('resize', handleResize)

  // 添加键盘事件监听
  document.addEventListener('keydown', handleKeydown)

  // 监听系统主题变化
  const mediaQuery = window.matchMedia('(prefers-color-scheme: dark)')
  const handleThemeChange = (e: MediaQueryListEvent) => {
    // 只有在用户没有手动设置过时才自动切换
    if (localStorage.getItem('darkMode') === null) {
      isDarkMode.value = e.matches
      if (e.matches) {
        document.documentElement.classList.add('dark')
      } else {
        document.documentElement.classList.remove('dark')
      }
    }
  }
  mediaQuery.addEventListener('change', handleThemeChange)

  // 组件卸载时清理事件监听
  return () => {
    window.removeEventListener('resize', handleResize)
    document.removeEventListener('keydown', handleKeydown)
    mediaQuery.removeEventListener('change', handleThemeChange)
    clearTimeout(resizeTimeout)
    if (searchDebounceTimer.value) {
      clearTimeout(searchDebounceTimer.value)
    }
  }
})

// 处理键盘事件
const handleKeydown = (event: KeyboardEvent) => {
  const currentBookmarks = filteredBookmarks.value

  // 如果没有书签，不处理方向键
  if (currentBookmarks.length === 0) return

  // 检查焦点是否在搜索框中
  const activeElement = document.activeElement
  const isSearchInputFocused = activeElement &&
    (activeElement as HTMLElement).tagName === 'INPUT' &&
    (activeElement as HTMLInputElement).placeholder?.includes('搜索书签')

  const maxRows = Math.ceil(currentBookmarks.length / gridLayout.value.columnsPerRow)

  switch (event.key) {
    case 'ArrowDown':
      event.preventDefault()
      isKeyboardNavigation.value = true
      // 移除搜索框焦点，将焦点转移到书签矩阵
      if (document.activeElement && 'blur' in document.activeElement) {
        (document.activeElement as HTMLElement).blur()
      }

      if (selectedRow.value === -1) {
        // 从搜索框进入书签矩阵，选中第一个书签（第一行第一列）
        selectedRow.value = 0
        selectedCol.value = 0
      } else {
        // 已在书签矩阵中，向下移动到下一行
        const nextRow = selectedRow.value + 1
        if (nextRow < maxRows) {
          selectedRow.value = nextRow
          // 确保选中的列在当前行的范围内，避免超出边界
          const maxColInRow = Math.min(gridLayout.value.columnsPerRow - 1,
                                      currentBookmarks.length - nextRow * gridLayout.value.columnsPerRow - 1)
          selectedCol.value = Math.min(selectedCol.value, maxColInRow)
        }
      }
      scrollToSelectedBookmark() // 滚动到选中的书签位置
      break

    case 'ArrowUp':
      event.preventDefault()
      isKeyboardNavigation.value = true
      if (selectedRow.value > 0) {
        // 已在书签矩阵中，向上移动到上一行
        if (document.activeElement && 'blur' in document.activeElement) {
          (document.activeElement as HTMLElement).blur()
        }
        selectedRow.value = selectedRow.value - 1
        // 确保选中的列在当前行的范围内，避免超出边界
        const maxColInRow = Math.min(gridLayout.value.columnsPerRow - 1,
                                    currentBookmarks.length - selectedRow.value * gridLayout.value.columnsPerRow - 1)
        selectedCol.value = Math.min(selectedCol.value, maxColInRow)
      } else if (selectedRow.value === 0) {
        // 从第一行向上，回到搜索框
        selectedRow.value = -1
        selectedCol.value = 0
        // 聚焦到搜索框，方便用户重新输入搜索内容
        const searchInput = document.querySelector('input[placeholder*="搜索书签"]') as HTMLInputElement
        if (searchInput) {
          searchInput.focus()
        }
      }
      break

    case 'ArrowLeft':
      event.preventDefault()
      isKeyboardNavigation.value = true
      // 移除搜索框焦点
      if (document.activeElement && 'blur' in document.activeElement) {
        (document.activeElement as HTMLElement).blur()
      }
      if (selectedRow.value >= 0) {
        if (selectedCol.value > 0) {
          // 向左移动到前一列
          selectedCol.value = selectedCol.value - 1
        } else {
          // 在第一列时，移动到上一行的最后一列
          if (selectedRow.value > 0) {
            selectedRow.value = selectedRow.value - 1
            const maxColInRow = Math.min(gridLayout.value.columnsPerRow - 1,
                                        currentBookmarks.length - selectedRow.value * gridLayout.value.columnsPerRow - 1)
            selectedCol.value = maxColInRow
          }
        }
        scrollToSelectedBookmark()
      }
      break

    case 'ArrowRight':
      event.preventDefault()
      isKeyboardNavigation.value = true
      // 移除搜索框焦点
      if (document.activeElement && 'blur' in document.activeElement) {
        (document.activeElement as HTMLElement).blur()
      }
      if (selectedRow.value >= 0) {
        const maxColInRow = Math.min(gridLayout.value.columnsPerRow - 1,
                                    currentBookmarks.length - selectedRow.value * gridLayout.value.columnsPerRow - 1)
        if (selectedCol.value < maxColInRow) {
          // 向右移动到下一列
          selectedCol.value = selectedCol.value + 1
        } else {
          // 在最后一列时，移动到下一行的第一列
          const nextRow = selectedRow.value + 1
          if (nextRow < maxRows) {
            selectedRow.value = nextRow
            selectedCol.value = 0
          }
        }
        scrollToSelectedBookmark()
      }
      break

    case 'Enter':
      // 如果焦点在搜索框中，不处理回车键（让模板中的 @keydown.enter 处理）
      if (isSearchInputFocused) {
        return // 搜索框的回车事件由模板处理器处理
      }

      // 判断当前焦点位置：selectedRow.value = -1 表示在搜索框，>= 0 表示在书签矩阵中
      const currentIndex = selectedBookmarkIndex.value

      if (selectedRow.value >= 0 && currentIndex >= 0 && currentIndex < currentBookmarks.length) {
        // 用户已使用方向键选择了书签，回车打开选中的书签
        event.preventDefault()
        openSelectedBookmark(true) // 在当前标签页打开书签
      }
      // 注意：这里不再调用 handleSearchEnter()，因为只有在搜索框有焦点时才会执行搜索
      break

    case 'Escape':
      // ESC键取消选中
      selectedRow.value = -1
      selectedCol.value = 0
      isKeyboardNavigation.value = false
      break
  }
}

// 打开选中的书签
const openSelectedBookmark = async (openInCurrentTab: boolean = true) => {
  const currentBookmarks = filteredBookmarks.value
  const currentIndex = selectedBookmarkIndex.value
  if (currentIndex < 0 || currentIndex >= currentBookmarks.length) return

  const bookmark = currentBookmarks[currentIndex]

  // 创建一个模拟的鼠标事件
  const mockEvent = new MouseEvent('click', {
    button: 0, // 左键
    ctrlKey: !openInCurrentTab, // 右键时在新标签页打开
    metaKey: false,
    bubbles: true,
    cancelable: true
  })

  await handleBookmarkClick(bookmark, mockEvent)
}

// 滚动到选中的书签
const scrollToSelectedBookmark = () => {
  // 延迟执行以确保DOM已更新
  setTimeout(() => {
    const selectedElement = document.querySelector('.bookmark-selected')
    if (selectedElement) {
      selectedElement.scrollIntoView({
        behavior: 'smooth',
        block: 'center'
      })
    }
  }, 50)
}

// 重置选中状态（当书签列表变化时）
const resetSelection = () => {
  selectedRow.value = -1
  selectedCol.value = 0
  isKeyboardNavigation.value = false
}

// 处理鼠标悬停事件
const handleMouseEnter = (index: number) => {
  // 鼠标悬停时重置键盘导航模式
  isKeyboardNavigation.value = false
  const { row, col } = getRowCol(index)
  selectedRow.value = row
  selectedCol.value = col
}

// 处理搜索框回车事件
const handleSearchEnter = async () => {
  const query = searchQuery.value.trim()
  if (!query) return

  // 如果有书签搜索结果，选中第一个书签
  if (bookmarks.value.length > 0) {
    const firstBookmark = bookmarks.value[0]
    window.location.href = firstBookmark.url
    return
  }

  // 如果没有书签搜索结果，使用 Chrome search API 进行搜索
  try {
    // 检查是否在 Chrome 扩展环境中并且 chrome.search API 可用
    if (typeof chrome !== 'undefined' && chrome.search && chrome.search.query) {
      console.log('使用 Chrome search API 搜索:', query)

      // 使用 Chrome search API 进行搜索
      chrome.search.query({
        text: query,
        disposition: 'NEW_TAB' // 在新标签页中打开搜索结果
      }, (results: any) => {
        if (chrome.runtime.lastError) {
          console.error('Chrome search API 错误:', chrome.runtime.lastError)
          // 如果 API 调用失败，回退到传统搜索引擎
          fallbackToWebSearch(query)
        } else {
          console.log('Chrome search API 搜索结果:', results)
          // API 调用成功，Chrome 会自动处理搜索结果页面的打开
        }
      })
    } else {
      console.log('Chrome search API 不可用，使用传统搜索引擎')
      // 如果 Chrome search API 不可用，回退到传统搜索引擎
      fallbackToWebSearch(query)
    }
  } catch (error) {
    console.error('Chrome search API 调用失败:', error)
    // 出错时回退到传统搜索引擎
    fallbackToWebSearch(query)
  }
}

// 回退到传统搜索引擎的函数
const fallbackToWebSearch = async (query: string) => {
  try {
    const config = await StorageService.getConfig()
    const defaultEngine = config.defaultSearchEngine || 'baidu'

    // 找到对应的搜索引擎
    const searchEngine = defaultSearchEngines.value.find(engine => engine.id === `search-${defaultEngine}`) as (BookmarkResp & { searchUrl: string }) | undefined

    if (searchEngine && searchEngine.searchUrl) {
      const searchUrl = searchEngine.searchUrl.replace('{query}', encodeURIComponent(query))
      console.log(`回退使用${searchEngine.name}搜索:`, searchUrl)
      window.location.href = searchUrl
    } else {
      // 如果找不到配置的搜索引擎，回退到百度
      const searchUrl = 'https://www.baidu.com/s?wd={query}'.replace('{query}', encodeURIComponent(query))
      console.log('回退到百度搜索:', searchUrl)
      window.location.href = searchUrl
    }
  } catch (error) {
    console.error('获取默认搜索引擎配置失败:', error)
    // 出错时回退到百度
    const searchUrl = 'https://www.baidu.com/s?wd={query}'.replace('{query}', encodeURIComponent(query))
    console.log('最终回退到百度搜索:', searchUrl)
    window.location.href = searchUrl
  }
}

// 监听搜索输入变化
watch(searchQuery, (newQuery) => {
  // 搜索内容变化时重置选中状态
  resetSelection()
  debouncedSearch(newQuery)
}, { immediate: false })

// 监听书签列表变化，重置选中状态
watch(filteredBookmarks, () => {
  resetSelection()
})
</script>

<template>
  <div class="min-h-screen relative" :style="backgroundStyle">
    <!-- 背景遮罩层 -->
    <div v-if="backgroundConfig.enabled" class="absolute inset-0 bg-black/20"></div>

    <!-- 主要内容区域 -->
    <div class="relative z-10 min-h-screen bg-background/80 text-foreground p-8" :style="backdropStyle">
    <!-- 顶部区域 -->
    <div class="flex items-center justify-between mb-8">
      <div :class="[
        'backdrop-blur-md rounded-2xl px-6 py-4 shadow-lg border',
        backgroundConfig.source === 'blank'
          ? 'bg-white/90 dark:bg-gray-800/90 border-gray-200 dark:border-gray-700'
          : 'bg-white/10 dark:bg-black/20 border-white/20 dark:border-white/10'
      ]">
        <h1 :class="[
          'text-4xl font-bold mb-2 text-shadow-lg drop-shadow-2xl',
          backgroundConfig.source === 'blank'
            ? 'text-gray-900 dark:text-white'
            : 'text-white dark:text-white'
        ]">{{ welcomeConfig.title }}</h1>
        <p :class="[
          'drop-shadow-lg',
          backgroundConfig.source === 'blank'
            ? 'text-gray-600 dark:text-gray-300'
            : 'text-white/80 dark:text-white/70'
        ]">{{ welcomeConfig.subtitle }}</p>
      </div>
      <div :class="[
        'flex items-center gap-2 backdrop-blur-md rounded-2xl p-2 shadow-lg border',
        backgroundConfig.source === 'blank'
          ? 'bg-white/90 dark:bg-gray-800/90 border-gray-200 dark:border-gray-700'
          : 'bg-white/10 dark:bg-black/20 border-white/20 dark:border-white/10'
      ]">
        <!-- Sinan 主页按钮 -->
        <Button variant="ghost" size="icon" @click="openSinanHomepage"
                :class="[
                  'h-10 w-10 transition-all duration-200',
                  backgroundConfig.source === 'blank'
                    ? 'text-gray-700 dark:text-gray-200 hover:bg-gray-200 dark:hover:bg-gray-700'
                    : 'text-white dark:text-white hover:bg-white/20 dark:hover:bg-white/10'
                ]">
          <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none"
            stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <path d="m3 9 9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z" />
            <polyline points="9,22 9,12 15,12 15,22" />
          </svg>
        </Button>
        <!-- 新增书签按钮 -->
        <Button variant="ghost" size="icon" @click="openAddBookmarkDialog"
                :class="[
                  'h-10 w-10 transition-all duration-200',
                  backgroundConfig.source === 'blank'
                    ? 'text-gray-700 dark:text-gray-200 hover:bg-gray-200 dark:hover:bg-gray-700'
                    : 'text-white dark:text-white hover:bg-white/20 dark:hover:bg-white/10'
                ]">
          <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none"
            stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <path d="M12 5v14M5 12h14" />
          </svg>
        </Button>
        <!-- 暗黑模式切换按钮 -->
        <Button variant="ghost" size="icon" @click="toggleDarkMode"
                :class="[
                  'h-10 w-10 transition-all duration-200',
                  backgroundConfig.source === 'blank'
                    ? 'text-gray-700 dark:text-gray-200 hover:bg-gray-200 dark:hover:bg-gray-700'
                    : 'text-white dark:text-white hover:bg-white/20 dark:hover:bg-white/10'
                ]">
          <!-- 太阳图标（浅色模式） -->
          <svg v-if="isDarkMode" xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none"
            stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <circle cx="12" cy="12" r="5" />
            <path d="M12 1v2M12 21v2M4.22 4.22l1.42 1.42M18.36 18.36l1.42 1.42M1 12h2M21 12h2M4.22 19.78l1.42-1.42M18.36 5.64l1.42-1.42" />
          </svg>
          <!-- 月亮图标（暗黑模式） -->
          <svg v-else xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none"
            stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z" />
          </svg>
        </Button>
        <!-- 刷新按钮 -->
        <Button variant="ghost" size="icon" @click="handleRefresh" :disabled="isRefreshing"
                :class="[
                  'h-10 w-10 transition-all duration-200 disabled:opacity-50',
                  backgroundConfig.source === 'blank'
                    ? 'text-gray-700 dark:text-gray-200 hover:bg-gray-200 dark:hover:bg-gray-700'
                    : 'text-white dark:text-white hover:bg-white/20 dark:hover:bg-white/10'
                ]">
        <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none"
          stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"
          :class="{ 'animate-spin': isRefreshing }">
          <path d="M3 12a9 9 0 0 1 9-9 9.75 9.75 0 0 1 6.74 2.74L21 8" />
          <path d="M21 3v5h-5" />
          <path d="M21 12a9 9 0 0 1-9 9 9.75 9.75 0 0 1-6.74-2.74L3 16" />
          <path d="M3 21v-5h5" />
        </svg>
        </Button>
      </div>
    </div>

    <!-- 搜索框 -->
    <div class="mb-8 max-w-md mx-auto relative">
      <div class="bg-white/20 dark:bg-black/30 backdrop-blur-lg rounded-2xl p-1 shadow-xl border border-white/30 dark:border-white/20">
        <Input v-model="searchQuery" placeholder="搜索书签名称、网址、描述..."
               class="w-full bg-white/80 dark:bg-black/60 border-0 rounded-xl shadow-none backdrop-blur-sm
                      placeholder:text-gray-600 dark:placeholder:text-gray-300
                      text-gray-900 dark:text-white
                      focus:bg-white/90 dark:focus:bg-black/70 transition-all duration-200"
               @keydown.enter="handleSearchEnter" />
      </div>
      <div v-if="isSearching" class="absolute right-4 top-1/2 transform -translate-y-1/2">
        <svg class="animate-spin h-4 w-4 text-gray-600 dark:text-gray-300" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
          <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
          <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
        </svg>
      </div>
    </div>

    <!-- 错误提示 -->
    <Alert v-if="errorAlert.show" variant="destructive" class="mb-6 max-w-2xl">
      <AlertDescription>
        {{ errorAlert.message }}
      </AlertDescription>
    </Alert>

    <!-- 加载状态 -->
    <div v-if="isLoading" class="flex items-center justify-center h-64">
      <div class="text-muted-foreground">加载中...</div>
    </div>

    <!-- 书签网格 -->
    <div v-else-if="filteredBookmarks.length > 0" class="grid gap-4 auto-fill-grid">
      <div v-for="(bookmark, index) in filteredBookmarks" :key="bookmark.id" @click="handleBookmarkClick(bookmark, $event)"
        @mousedown="handleMouseDown(bookmark, $event)" @mouseenter="handleMouseEnter(index)" @contextmenu.prevent :class="[
                'flex items-center gap-3 p-3 rounded-lg border bg-card text-card-foreground transition-all cursor-pointer overflow-hidden',
                {
                  'bookmark-selected ring-2 ring-blue-500 ring-opacity-60 bg-blue-50 dark:bg-blue-900/20 border-blue-300 dark:border-blue-600': selectedBookmarkIndex === index,
                  'shadow-sm hover:shadow-[0_0_20px_rgba(251,191,36,0.3)] border-amber-200/50 dark:border-amber-400/30 dark:hover:shadow-[0_0_20px_rgba(251,191,36,0.2)]': bookmark.star && selectedBookmarkIndex !== index,
                  'shadow-sm hover:shadow-md dark:hover:shadow-lg': !bookmark.star && selectedBookmarkIndex !== index
                }
              ]">
        <div class="flex items-center gap-3 h-full w-full overflow-hidden">
          <!-- 图标加载状态：skeleton -> 加载完成的图标 -->
          <div class="w-8 h-8 flex-shrink-0 flex items-center justify-center">
            <Skeleton 
              v-if="isFaviconLoading(bookmark.url) || !isFaviconLoaded(bookmark.url)" 
              class="w-8 h-8 rounded" 
              @vue:mounted="ensureFaviconLoading(bookmark.url)"
            />
            <img
                v-if="isValidIcon(bookmark.icon)"
                :src="String(bookmark.icon)"
                :alt="bookmark.name"
                class="h-full w-full object-cover"
                @error="(e) => (e.target as HTMLImageElement).src = '/icon48.png'"
            />
            <img 
              v-else
              :src="getCachedFavicon(bookmark.url)" 
              :alt="bookmark.name" 
              class="w-8 h-8 rounded"
              @error="($event.target as HTMLImageElement).style.display = 'none'" 
            />
          </div>
          <div class="flex-1 min-w-0 overflow-hidden">
            <p class="text-sm font-medium truncate max-w-full">{{ getDisplayName(bookmark) }}</p>
            <p class="text-xs text-muted-foreground truncate max-w-full">{{ bookmark.url }}</p>
          </div>
        </div>
      </div>
    </div>

    <!-- 无书签状态 -->
    <div v-else class="flex flex-col items-center justify-center h-64 text-muted-foreground">
      <svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 24 24" fill="none"
        stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="mb-4">
        <path d="m19 21-7-4-7 4V5a2 2 0 0 1 2-2h10a2 2 0 0 1 2 2v16z" />
      </svg>
      <p class="text-lg mb-2">暂无常用书签</p>
      <p class="text-sm">开始使用书签后，这里会显示您最常访问的内容</p>
    </div>

    <!-- 新增书签对话框 -->
    <div v-if="showAddBookmarkDialog" class="fixed inset-0 z-50 flex items-center justify-center">
      <!-- 背景遮罩 -->
      <div class="fixed inset-0 backdrop-blur-sm bg-black/20" @click="closeAddBookmarkDialog"></div>
      
      <!-- 对话框内容 -->
      <div class="relative bg-background border rounded-lg shadow-lg w-full max-w-md mx-4 p-6">
        <div class="flex items-center justify-between mb-4">
          <h2 class="text-lg font-semibold">添加新书签</h2>
          <Button variant="ghost" size="icon" @click="closeAddBookmarkDialog" class="h-6 w-6">
            <svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none"
              stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
              <path d="M18 6 6 18M6 6l12 12" />
            </svg>
          </Button>
        </div>
        
        <div class="space-y-4">
          <div>
            <label class="text-sm font-medium mb-1 block">网址 *</label>
            <Input 
              v-model="newBookmark.url" 
              placeholder="https://example.com" 
              class="w-full"
              @blur="fetchTitleFromUrl"
            />
          </div>
          
          <div>
            <label class="text-sm font-medium mb-1 block">书签名称 *</label>
            <Input 
              v-model="newBookmark.name" 
              placeholder="输入书签名称" 
              class="w-full"
            />
          </div>
          
          <div>
            <label class="text-sm font-medium mb-1 block">描述</label>
            <Textarea 
              v-model="newBookmark.description" 
              placeholder="输入描述（可选）" 
              class="w-full resize-none max-h-[4.5rem] overflow-y-auto"
              rows="3"
            />
          </div>
          
          <div>
            <label class="text-sm font-medium mb-1 block">选择空间</label>
            <Select v-model="newBookmark.namespaceId">
              <SelectTrigger class="w-full">
                <SelectValue placeholder="选择一个空间" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem 
                  v-for="namespace in namespaces" 
                  :key="namespace.id" 
                  :value="namespace.id"
                >
                  {{ namespace.name }}
                </SelectItem>
              </SelectContent>
            </Select>
          </div>
        </div>
        
        <!-- 按钮区域 -->
        <div class="flex justify-end gap-2 mt-6">
          <Button variant="outline" @click="closeAddBookmarkDialog">
            取消
          </Button>
          <Button @click="addBookmark">
            添加书签
          </Button>
        </div>
      </div>
    </div>
    </div>
  </div>
</template>

<style scoped>
.auto-fill-grid {
  grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
}

@media (max-width: 640px) {
  .auto-fill-grid {
    grid-template-columns: 1fr;
  }
}

@media (min-width: 1920px) {
  .auto-fill-grid {
    grid-template-columns: repeat(auto-fill, minmax(350px, 1fr));
  }
}

.line-clamp-2 {
  display: -webkit-box;
  -webkit-line-clamp: 2;
  line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}

/* 确保文本容器不会超出边界 */
.truncate {
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  max-width: 100%;
}

/* 确保 flex 容器正确处理溢出 */
.min-w-0 {
  min-width: 0;
}
</style>
