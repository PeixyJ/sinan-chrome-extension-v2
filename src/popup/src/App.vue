<script setup lang="ts">
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import Textarea from "@/components/ui/textarea/Textarea.vue";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Switch } from "@/components/ui/switch";
import { Alert, AlertDescription } from "@/components/ui/alert";
import { MultiSelect } from "@/components/ui/multi-select";
import Tabs from "@/components/ui/tabs/Tabs.vue";
import TabsList from "@/components/ui/tabs/TabsList.vue";
import TabsTrigger from "@/components/ui/tabs/TabsTrigger.vue";
import TabsContent from "@/components/ui/tabs/TabsContent.vue";
import { useColorMode } from '@vueuse/core'
import { onMounted, onUnmounted, ref, computed, watch, nextTick } from 'vue'
import { StorageService } from '../../shared/services/storage'
import { SinanApiService } from '../../shared/services/api'
import { BookmarkService } from '../../shared/services/bookmark'
import { IconCacheService } from '../../shared/services/iconCache'
import { NewtabBackgroundService } from '../../shared/services/tagBackground'
import type { SnSpace, TagResp } from '../../shared/types/api'
import ImageUpload from '@/components/ui/image-upload/ImageUpload.vue'
import BlurSlider from '@/components/ui/blur-slider/BlurSlider.vue'

const mode = useColorMode({
  modes: {
    light: 'light',
    dark: 'dark',
    auto: 'auto'
  },
  initialValue: 'auto'
})

const isLoading = ref(true)
const lastSyncTime = ref<number | undefined>()
const saveButtonText = ref('保存')
const isSaving = ref(false)
const originalConfig = ref<any>({})
const isSyncing = ref(false)
const syncButtonText = ref('重新同步')
const isDeleting = ref(false)
const deleteButtonText = ref('删除书签目录')
const syncAlert = ref<{ show: boolean; type: 'success' | 'error'; message: string }>({
  show: false,
  type: 'success',
  message: ''
})

// 新增书签相关状态
const isAddingBookmark = ref(false)
const namespaces = ref<SnSpace[]>([])
const tags = ref<TagResp[]>([])
const currentTab = ref({
  title: '',
  url: '',
  description: '',
  namespaceId: '',
  tagIds: [] as string[]
})

// 响应式引用来强制更新MultiSelect
const multiSelectKey = ref(0)

// Bing图片预览
const bingImageUrl = ref('')
const isLoadingBingImage = ref(false)
const addBookmarkAlert = ref<{ show: boolean; type: 'success' | 'error'; message: string }>({
  show: false,
  type: 'success',
  message: ''
})

// URL文本域
const urlTextarea = ref('')

// 表单状态持久化
const formValues = ref({
  serverUrl: 'https://sinan.host/api/',
  webUrl: 'https://sinan.host',
  apiKey: '',
  autoSync: false,
  syncInterval: '30',
  iconSource: 'google-s2' as 'google-s2' | 'sinan',

  // Newtab背景配置
  newtabBackgroundEnabled: true,
  newtabBackgroundSource: 'blank' as 'local' | 'blank' | 'bing' | 'urls',
  newtabBackgroundImage: '',
  newtabBackgroundUrls: '',
  newtabBackgroundBingUrl: 'https://www.bing.com/HPImageArchive.aspx?format=js&idx=0&n=1',
  newtabBlurEnabled: false,
  newtabBlurIntensity: 10,

  // 欢迎词配置
  welcomeTitle: 'Welcome to Sinan',
  welcomeSubtitle: "Let's hurry to our destination.",

  // 默认搜索引擎配置
  defaultSearchEngine: 'baidu',
})


const hasChanges = computed(() => {
  return (
    formValues.value.serverUrl !== originalConfig.value.serverUrl ||
    formValues.value.webUrl !== originalConfig.value.webUrl ||
    formValues.value.apiKey !== originalConfig.value.apiKey ||
    formValues.value.autoSync !== originalConfig.value.autoSync ||
    formValues.value.syncInterval !== originalConfig.value.syncInterval ||
    formValues.value.iconSource !== originalConfig.value.iconSource ||
    formValues.value.newtabBackgroundSource !== originalConfig.value.newtabBackgroundSource ||
    formValues.value.newtabBackgroundImage !== originalConfig.value.newtabBackgroundImage ||
    formValues.value.newtabBackgroundBingUrl !== originalConfig.value.newtabBackgroundBingUrl ||
    formValues.value.newtabBlurIntensity !== originalConfig.value.newtabBlurIntensity ||
    JSON.stringify(formValues.value.newtabBackgroundUrls) !== JSON.stringify(originalConfig.value.newtabBackgroundUrls) ||
    formValues.value.welcomeTitle !== originalConfig.value.welcomeTitle ||
    formValues.value.welcomeSubtitle !== originalConfig.value.welcomeSubtitle ||
    formValues.value.defaultSearchEngine !== originalConfig.value.defaultSearchEngine
  )
})

const lastSyncText = computed(() => {
  if (!lastSyncTime.value) return '尚未同步'

  const now = Date.now()
  const diff = now - lastSyncTime.value
  const minutes = Math.floor(diff / 60000)
  const hours = Math.floor(minutes / 60)
  const days = Math.floor(hours / 24)

  if (days > 0) return `${days}天前`
  if (hours > 0) return `${hours}小时前`
  if (minutes > 0) return `${minutes}分钟前`
  return '刚刚'
})

// URL处理相关计算属性
const totalUrlCount = computed(() => {
  return urlTextarea.value.split('\n').filter(line => line.trim()).length
})

const validUrlCount = computed(() => {
  const urls = urlTextarea.value.split('\n').filter(line => line.trim())
  return urls.filter(url => {
    try {
      new URL(url.trim())
      const trimmedUrl = url.trim()
      return /\.(jpg|jpeg|png|gif|webp|bmp|svg)(\?.*)?$/i.test(trimmedUrl) ||
             /\/(image|img)\//i.test(trimmedUrl) ||
             trimmedUrl.includes('unsplash') ||
             trimmedUrl.includes('pixabay') ||
             trimmedUrl.includes('pexels')
    } catch {
      return false
    }
  }).length
})


onMounted(async () => {
  try {
    const config = await StorageService.getConfig()
    originalConfig.value = { ...config }

    // 更新持久化表单值
    formValues.value = {
      serverUrl: config.serverUrl,
      webUrl: config.webUrl || 'https://sinan.host',
      apiKey: config.apiKey,
      autoSync: config.autoSync,
      syncInterval: config.syncInterval,
      iconSource: config.iconSource,

      // Newtab背景配置
      newtabBackgroundEnabled: config.newtabBackgroundEnabled,
      newtabBackgroundSource: config.newtabBackgroundSource,
      newtabBackgroundImage: config.newtabBackgroundImage || '',
      newtabBackgroundUrls: config.newtabBackgroundUrls || '[]',
      newtabBackgroundBingUrl: config.newtabBackgroundBingUrl || 'https://www.bing.com/HPImageArchive.aspx?format=js&idx=0&n=1',
      newtabBlurEnabled: config.newtabBlurEnabled,
      newtabBlurIntensity: config.newtabBlurIntensity,

      // 欢迎词配置
      welcomeTitle: config.welcomeTitle || 'Welcome to Sinan',
      welcomeSubtitle: config.welcomeSubtitle || "Let's hurry to our destination.",

      // 默认搜索引擎配置
      defaultSearchEngine: config.defaultSearchEngine || 'baidu',
    }

    lastSyncTime.value = config.lastSyncTime

    // 初始化URL文本域
    try {
      const urls = config.newtabBackgroundUrls ? JSON.parse(config.newtabBackgroundUrls) : []
      urlTextarea.value = Array.isArray(urls) ? urls.join('\n') : ''
    } catch (error) {
      console.error('解析初始背景URL失败:', error)
      urlTextarea.value = ''
    }

    // 初始化当前标签页信息
    await refreshCurrentTabInfo()

    // 启动选择变化监听
    const cleanup = watchSelectionChanges()

    // 在组件卸载时清理监听器
    onUnmounted(() => {
      cleanup()
    })
  } catch (error) {
    console.error('Failed to load config:', error)
  } finally {
    isLoading.value = false
  }

})

// 监听URL文本域变化并同步到formValues
watch(urlTextarea, (newValue) => {
  const urls = newValue.split('\n')
    .map(line => line.trim())
    .filter(line => line)
  formValues.value.newtabBackgroundUrls = JSON.stringify(urls)
})

// 监听formValues.newtabBackgroundUrls变化并同步到文本域（用于重置等操作）
watch(() => formValues.value.newtabBackgroundUrls, (newUrls) => {
  try {
    const urls = newUrls ? JSON.parse(newUrls) : []
    const textContent = Array.isArray(urls) ? urls.join('\n') : ''
    if (urlTextarea.value !== textContent) {
      urlTextarea.value = textContent
    }
  } catch (error) {
    console.error('解析背景URL失败:', error)
    urlTextarea.value = ''
  }
})

const onSubmit = async () => {
  console.log('=== 开始保存配置 ===')
  console.log('hasChanges:', hasChanges.value)
  console.log('formValues:', formValues.value)

  if (!hasChanges.value) return

  isSaving.value = true
  saveButtonText.value = '保存中...'

  try {
    await StorageService.saveConfig({
      serverUrl: formValues.value.serverUrl,
      webUrl: formValues.value.webUrl,
      apiKey: formValues.value.apiKey,
      autoSync: formValues.value.autoSync,
      syncInterval: formValues.value.syncInterval,
      iconSource: formValues.value.iconSource,

      // Newtab背景配置
      newtabBackgroundEnabled: formValues.value.newtabBackgroundEnabled,
      newtabBackgroundSource: formValues.value.newtabBackgroundSource,
      newtabBackgroundImage: formValues.value.newtabBackgroundImage,
      newtabBackgroundUrls: formValues.value.newtabBackgroundUrls || '[]',
      newtabBlurEnabled: formValues.value.newtabBlurIntensity > 0,
      newtabBlurIntensity: formValues.value.newtabBlurIntensity,

      // 欢迎词配置
      welcomeTitle: formValues.value.welcomeTitle,
      welcomeSubtitle: formValues.value.welcomeSubtitle,

      // 默认搜索引擎配置
      defaultSearchEngine: formValues.value.defaultSearchEngine,
    })
    
    // 更新 API 实例以使用新的配置
    await SinanApiService.refreshInstance()
    
    // 如果图标来源发生变化，清除图标缓存
    if (originalConfig.value.iconSource !== formValues.value.iconSource) {
      await IconCacheService.clearCache()
    }
    
    originalConfig.value = { ...formValues.value }
    console.log('=== 配置保存成功 ===')
    console.log('新的originalConfig:', originalConfig.value)
    saveButtonText.value = '保存成功 刷新后生效'
    setTimeout(() => {
      saveButtonText.value = '保存'
    }, 2000)
  } catch (error) {
    console.error('Failed to save config:', error)
    saveButtonText.value = '保存失败'
    setTimeout(() => {
      saveButtonText.value = '保存'
    }, 2000)
  } finally {
    isSaving.value = false
  }
}

const handleReset = () => {
  // 恢复到原始配置
  formValues.value = { ...originalConfig.value }
}

const handleRestoreDefault = () => {
  // 恢复到默认配置
  formValues.value = {
    serverUrl: 'https://sinan.host/api/',
    webUrl: 'https://sinan.host',
    apiKey: '',
    autoSync: false,
    syncInterval: '30',
    iconSource: 'google-s2',

    // Newtab背景默认配置
    newtabBackgroundEnabled: true,
    newtabBackgroundSource: 'blank',
    newtabBackgroundImage: '',
    newtabBackgroundUrls: '',
    newtabBackgroundBingUrl: 'https://www.bing.com/HPImageArchive.aspx?format=js&idx=0&n=1',
    newtabBlurEnabled: false,
    newtabBlurIntensity: 10,

    // 欢迎词默认配置
    welcomeTitle: 'Welcome to Sinan',
    welcomeSubtitle: "Let's hurry to our destination.",

    // 默认搜索引擎默认配置
    defaultSearchEngine: 'baidu',
  }
}

const handleSync = async () => {
  if (isSyncing.value) return
  
  isSyncing.value = true
  syncButtonText.value = '同步中...'
  syncAlert.value.show = false
  
  try {
    console.log('开始重新同步书签...')
    const result = await BookmarkService.resyncBookmarks()
    
    await StorageService.updateLastSyncTime()
    lastSyncTime.value = Date.now()
    
    const successMsg = `同步成功！删除了 ${result.deleted} 个旧文件夹，创建了 ${result.created} 个书签空间`
    console.log(successMsg)
    
    syncAlert.value = {
      show: true,
      type: 'success',
      message: successMsg
    }
    syncButtonText.value = '同步成功'
    
    setTimeout(() => {
      syncButtonText.value = '重新同步'
      syncAlert.value.show = false
    }, 5000)
  } catch (error) {
    const errorMsg = `重新同步失败: ${error instanceof Error ? error.message : String(error)}`
    console.error('重新同步过程中出错:', error)
    
    syncAlert.value = {
      show: true,
      type: 'error',
      message: errorMsg
    }
    syncButtonText.value = '同步失败'
    
    setTimeout(() => {
      syncButtonText.value = '重新同步'
      syncAlert.value.show = false
    }, 5000)
  } finally {
    isSyncing.value = false
  }
}

const handleOpenSinan = () => {
  const url = formValues.value.webUrl || 'https://sinan.host'
  if (typeof chrome !== 'undefined' && chrome.tabs) {
    chrome.tabs.create({ url })
  } else {
    // Fallback for development
    window.open(url, '_blank')
  }
}

const handleDeleteBookmarks = async () => {
  if (isDeleting.value) return
  
  isDeleting.value = true
  deleteButtonText.value = '删除中...'
  syncAlert.value.show = false
  
  try {
    console.log('删除Sinan书签目录...')
    const deletedCount = await BookmarkService.deleteAllSinanFolders()
    
    const successMsg = `成功删除 ${deletedCount} 个Sinan书签目录`
    console.log(successMsg)
    
    syncAlert.value = {
      show: true,
      type: 'success',
      message: successMsg
    }
    deleteButtonText.value = '删除成功'
    
    setTimeout(() => {
      deleteButtonText.value = '删除书签目录'
      syncAlert.value.show = false
    }, 5000)
  } catch (error) {
    const errorMsg = `删除书签目录失败: ${error instanceof Error ? error.message : String(error)}`
    console.error('删除书签目录时出错:', error)
    
    syncAlert.value = {
      show: true,
      type: 'error',
      message: errorMsg
    }
    deleteButtonText.value = '删除失败'
    
    setTimeout(() => {
      deleteButtonText.value = '删除书签目录'
      syncAlert.value.show = false
    }, 5000)
  } finally {
    isDeleting.value = false
  }
}

// 监听空间和标签选择变化并保存到缓存
const watchSelectionChanges = () => {
  // 监听空间选择变化
  const unwatchNamespace = watch(() => currentTab.value.namespaceId, async (newNamespaceId) => {
    if (newNamespaceId) {
      console.log('空间选择发生变化，保存到缓存:', newNamespaceId)
      await StorageService.saveLastSelected(newNamespaceId, currentTab.value.tagIds)
    }
  })

  // 监听标签选择变化
  const unwatchTags = watch(() => currentTab.value.tagIds, async (newTagIds) => {
    console.log('标签选择发生变化，保存到缓存:', newTagIds)
    await StorageService.saveLastSelected(currentTab.value.namespaceId, newTagIds)
  })

  // 返回清理函数
  return () => {
    unwatchNamespace()
    unwatchTags()
  }
}

// 获取当前标签页信息
const getCurrentTabInfo = async () => {
  try {
    if (typeof chrome !== 'undefined' && chrome.tabs) {
      const [tab] = await chrome.tabs.query({ active: true, currentWindow: true })
      if (tab) {
        currentTab.value.title = tab.title || ''
        currentTab.value.url = tab.url || ''
        
        console.log('获取到基本标签页信息:', { title: tab.title, url: tab.url })
        
        // 尝试获取页面的描述信息
        try {
          if (tab.id && tab.url && !tab.url.startsWith('chrome://') && !tab.url.startsWith('chrome-extension://') && !tab.url.startsWith('moz-extension://')) {
            console.log('尝试执行content script获取描述信息...', { tabId: tab.id, url: tab.url })
            
            // 先检查是否有权限
            try {
              await chrome.scripting.executeScript({
                target: { tabId: tab.id },
                func: () => { return 'test' }
              })
              console.log('权限检查通过')
            } catch (permError) {
              console.log('权限检查失败:', permError)
              return
            }
            
            const results = await chrome.scripting.executeScript({
              target: { tabId: tab.id },
              func: () => {
                try {
                  // 更全面的选择器
                  const selectors = [
                    'meta[name="description"]',
                    'meta[name="Description"]',
                    'meta[property="og:description"]',
                    'meta[property="og:Description"]',
                    'meta[name="twitter:description"]',
                    'meta[name="twitter:Description"]'
                  ]
                  
                  let description = ''
                  
                  for (const selector of selectors) {
                    const meta = document.querySelector(selector)
                    if (meta) {
                      const content = meta.getAttribute('content')
                      if (content && content.trim().length > 0) {
                        description = content.trim()
                        break
                      }
                    }
                  }
                  
                  // 如果还是没找到，尝试获取页面的第一个段落
                  if (!description) {
                    const firstP = document.querySelector('p')
                    if (firstP && firstP.textContent) {
                      description = firstP.textContent.trim().substring(0, 200)
                    }
                  }
                  
                  return {
                    description,
                    metaTags: selectors.map(sel => {
                      const meta = document.querySelector(sel)
                      return {
                        selector: sel,
                        content: meta?.getAttribute('content') || null
                      }
                    })
                  }
                } catch (err) {
                  return { error: err instanceof Error ? err.message : String(err), description: '' }
                }
              }
            })
            
            console.log('Content script执行结果:', results)
            
            if (results[0]?.result) {
              const result = results[0].result
              if (result.description) {
                currentTab.value.description = result.description
                console.log('成功获取描述:', result.description)
              } else {
                console.log('未找到有效的描述信息，meta标签情况:', result.metaTags)
              }
            }
          } else {
            console.log('跳过特殊页面的描述获取:', tab.url)
          }
        } catch (error) {
          console.log('获取页面描述失败:', error)
          if (error instanceof Error) {
            console.log('错误详情:', error.message)
            if (error.message?.includes('Cannot access')) {
              console.log('权限不足，无法获取页面描述')
            }
          }
        }
        
        console.log('最终获取的标签页信息:', currentTab.value)
      }
    }
  } catch (error) {
    console.error('获取当前标签页信息失败:', error)
  }
}

// 获取所有namespace
const loadNamespaces = async () => {
  try {
    const response = await SinanApiService.getSpaces()
    if (response.code === 0) {
      namespaces.value = response.data

      // 尝试从缓存中恢复上次选择的空间
      const lastSelected = await StorageService.getLastSelected()
      if (lastSelected.namespaceId && namespaces.value.some(ns => ns.id === lastSelected.namespaceId)) {
        currentTab.value.namespaceId = lastSelected.namespaceId
      } else if (namespaces.value.length > 0 && !currentTab.value.namespaceId) {
        // 如果缓存中没有有效的namespace，默认选择第一个
        currentTab.value.namespaceId = namespaces.value[0].id
      }

      console.log('加载namespace成功:', response.data.length, '个空间')
    } else {
      console.error('获取namespace列表失败:', response.message)
    }
  } catch (error) {
    console.error('获取namespace列表时出错:', error)
  }
}

// 获取所有标签
const loadTags = async () => {
  try {
    const response = await SinanApiService.getTags()
    if (response.code === 0) {
      // 使用响应式更新
      tags.value = response.data
      console.log('标签数据已加载:', tags.value.length, '个标签')

      // 尝试从缓存中恢复上次选择的标签
      const lastSelected = await StorageService.getLastSelected()
      console.log('从缓存中获取的上次选择:', lastSelected)

      if (lastSelected.tagIds && Array.isArray(lastSelected.tagIds) && lastSelected.tagIds.length > 0) {
        // 只保留仍然存在的标签
        const validTagIds = lastSelected.tagIds.filter(tagId =>
          tags.value.some(tag => tag.id === tagId)
        )
        console.log('有效的标签ID:', validTagIds)
        console.log('无效的标签ID:', lastSelected.tagIds.filter(tagId =>
          !tags.value.some(tag => tag.id === tagId)
        ))

        // 使用nextTick确保DOM更新
        await nextTick()
        // 直接设置标签ID数组，使用深拷贝确保响应性
        currentTab.value.tagIds = [...validTagIds]
        console.log('已恢复标签选择:', currentTab.value.tagIds)
        console.log('currentTab.tagIds 类型:', typeof currentTab.value.tagIds, 'isArray:', Array.isArray(currentTab.value.tagIds))
        console.log('标签绑定状态 - currentTab.tagIds:', currentTab.value.tagIds)
        console.log('标签绑定状态 - tags数据:', tags.value)

        // 强制更新MultiSelect组件
        multiSelectKey.value++
        await nextTick()
      } else {
        console.log('缓存中没有找到标签选择或标签选择为空')
        await nextTick()
        currentTab.value.tagIds = []
      }

      console.log('加载标签成功:', response.data.length, '个标签')
    } else {
      console.error('获取标签列表失败:', response.message)
    }
  } catch (error) {
    console.error('获取标签列表时出错:', error)
  }
}

// 刷新当前标签页信息
const refreshCurrentTabInfo = async () => {
  console.log('刷新标签页信息开始...')
  addBookmarkAlert.value.show = false

  // 清空当前信息（但保留标签ID以便后续恢复）
  currentTab.value = {
    title: '',
    url: '',
    description: '',
    namespaceId: '',
    tagIds: [] // 先清空，让loadTags从缓存中恢复
  }

  // 获取当前标签页信息
  await getCurrentTabInfo()

  // 加载空间和标签数据，并从缓存中恢复选择
  await Promise.all([loadNamespaces(), loadTags()])

  console.log('刷新标签页信息完成，最终标签选择:', currentTab.value.tagIds)
}

// 添加书签到Sinan
const addBookmarkToSinan = async () => {
  if (!currentTab.value.title.trim() || !currentTab.value.url.trim()) {
    addBookmarkAlert.value = {
      show: true,
      type: 'error',
      message: '书签名称和网址不能为空'
    }
    return
  }

  isAddingBookmark.value = true
  
  try {
    const response = await SinanApiService.addBookmark({
      name: currentTab.value.title.trim(),
      url: currentTab.value.url.trim(),
      description: currentTab.value.description.trim() || undefined,
      namespaceId: currentTab.value.namespaceId || undefined,
      tagsIds: currentTab.value.tagIds.length > 0 ? currentTab.value.tagIds : undefined
    })

    if (response.code === 0) {
      console.log('书签添加成功:', response.data)

      // 保存当前选择的空间和标签到缓存
      await StorageService.saveLastSelected(
        currentTab.value.namespaceId,
        currentTab.value.tagIds
      )
      console.log('已保存当前选择到缓存:', {
        namespaceId: currentTab.value.namespaceId,
        tagIds: currentTab.value.tagIds
      })

      addBookmarkAlert.value = {
        show: true,
        type: 'success',
        message: '书签添加成功！'
      }

      // 3秒后自动隐藏成功提示
      setTimeout(() => {
        addBookmarkAlert.value.show = false
      }, 3000)
    } else {
      addBookmarkAlert.value = {
        show: true,
        type: 'error',
        message: `添加书签失败: ${response.message}`
      }
    }
  } catch (error) {
    console.error('添加书签失败:', error)
    addBookmarkAlert.value = {
      show: true,
      type: 'error',
      message: `添加书签失败: ${error instanceof Error ? error.message : String(error)}`
    }
  } finally {
    isAddingBookmark.value = false
  }
}

// 切换黑夜模式
const toggleDarkMode = () => {
  mode.value = mode.value === 'dark' ? 'light' : 'dark'
}

// 预览Bing每日一图
const previewBingImage = async () => {
  if (isLoadingBingImage.value) return

  isLoadingBingImage.value = true
  try {
    bingImageUrl.value = await NewtabBackgroundService.getBingDailyImage()
  } catch (error) {
    console.error('获取Bing图片失败:', error)
    bingImageUrl.value = ''
  } finally {
    isLoadingBingImage.value = false
  }
}

</script>


<template>
  <div :class="mode" class="min-h-full">
    <div class="p-3 w-[360px] h-[600px] bg-background shadow-lg border border-border flex flex-col gap-6">
      <!-- 标题 -->
      <div class="text-lg text-primary flex items-center justify-between">
        <span>Sinan 书签管理</span>
        <!-- 黑夜模式切换按钮 -->
        <Button variant="ghost" size="icon" @click="toggleDarkMode" class="h-8 w-8">
          <!-- 太阳图标（浅色模式） -->
          <svg v-if="mode === 'dark'" xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none"
            stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <circle cx="12" cy="12" r="5" />
            <path d="M12 1v2M12 21v2M4.22 4.22l1.42 1.42M18.36 18.36l1.42 1.42M1 12h2M21 12h2M4.22 19.78l1.42-1.42M18.36 5.64l1.42-1.42" />
          </svg>
          <!-- 月亮图标（暗黑模式） -->
          <svg v-else xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none"
            stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z" />
          </svg>
        </Button>
      </div>

      <!-- Tab导航 -->
      <Tabs default-value="bookmark" class="flex flex-col flex-1 overflow-hidden">
        <TabsList class="grid w-full grid-cols-3">
          <TabsTrigger value="main">基础功能</TabsTrigger>
          <TabsTrigger value="bookmark">添加书签</TabsTrigger>
          <TabsTrigger value="settings">系统配置</TabsTrigger>
        </TabsList>

        <!-- 基础功能页面 -->
        <TabsContent value="main" class="p-3 flex flex-col h-full space-y-4 overflow-y-auto">
          <!-- 操作按钮 -->
          <div class="flex flex-col gap-4">
            <Button class="w-full" variant="default" @click="handleOpenSinan">打开Sinan主页</Button>
            <div class="flex gap-2">
              <Button
                class="flex-1"
                variant="outline"
                @click="handleSync"
                :disabled="isSyncing || isLoading || isDeleting"
              >
                {{ syncButtonText }}
              </Button>
              <Button
                class="flex-1"
                variant="destructive"
                @click="handleDeleteBookmarks"
                :disabled="isDeleting || isLoading || isSyncing"
              >
                {{ deleteButtonText }}
              </Button>
            </div>

            <!-- 同步状态提示 -->
            <Alert v-if="syncAlert.show" :variant="syncAlert.type === 'error' ? 'destructive' : 'default'">
              <AlertDescription>
                {{ syncAlert.message }}
              </AlertDescription>
            </Alert>
          </div>

          <div class="border-b border-border" />

          <!-- 欢迎词配置 -->
          <div class="space-y-4">
            <div class="space-y-2">
              <label class="text-sm font-medium leading-none peer-disabled:cursor-not-allowed peer-disabled:opacity-70">欢迎词标题</label>
              <Input
                v-model="formValues.welcomeTitle"
                placeholder="请输入欢迎词标题"
                autocomplete="off"
              />
            </div>

            <div class="space-y-2">
              <label class="text-sm font-medium leading-none peer-disabled:cursor-not-allowed peer-disabled:opacity-70">欢迎词内容</label>
              <Input
                v-model="formValues.welcomeSubtitle"
                placeholder="请输入欢迎词内容"
                autocomplete="off"
              />
            </div>

            <div class="space-y-2">
              <label class="text-sm font-medium leading-none peer-disabled:cursor-not-allowed peer-disabled:opacity-70">默认搜索引擎</label>
              <Select v-model="formValues.defaultSearchEngine">
                <SelectTrigger class="w-full">
                  <SelectValue placeholder="选择默认搜索引擎" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="baidu">百度</SelectItem>
                  <SelectItem value="google">Google</SelectItem>
                  <SelectItem value="bing">Bing</SelectItem>
                </SelectContent>
              </Select>
            </div>
          </div>

          <!-- 来源设置 -->
          <div class="grid grid-cols-2 gap-4">
            <!-- Newtab背景来源选择 -->
            <div class="space-y-2">
              <label class="text-sm font-medium leading-none peer-disabled:cursor-not-allowed peer-disabled:opacity-70">背景来源</label>
                <Select
                  v-model="formValues.newtabBackgroundSource"
                >
                  <SelectTrigger class="w-full">
                    <SelectValue placeholder="选择背景来源" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="blank">空</SelectItem>
                    <SelectItem value="local">本地图片</SelectItem>
                    <SelectItem value="urls">多个URL随机</SelectItem>
                    <SelectItem value="bing">Bing每日一图</SelectItem>
                  </SelectContent>
                </Select>
              </div>

              <!-- 图标来源设置 -->
              <div class="space-y-2">
                <label class="text-sm font-medium leading-none peer-disabled:cursor-not-allowed peer-disabled:opacity-70">图标来源</label>
                <Select
                  v-model="formValues.iconSource"
                >
                  <SelectTrigger class="w-full">
                    <SelectValue placeholder="选择图标来源" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="google-s2">Google S2</SelectItem>
                    <SelectItem value="sinan">Sinan服务</SelectItem>
                  </SelectContent>
                </Select>
              </div>
            </div>

            <!-- Newtab背景详细设置 -->
            <div class="space-y-4">
              <!-- 本地图片上传 -->
              <div v-if="formValues.newtabBackgroundSource === 'local'" class="space-y-2">
                <ImageUpload
                  v-model="formValues.newtabBackgroundImage"
                  label="上传背景图片"
                />
              </div>

              <!-- 多个URL输入 -->
              <div v-if="formValues.newtabBackgroundSource === 'urls'" class="space-y-2">
                <label class="text-sm font-medium leading-none peer-disabled:cursor-not-allowed peer-disabled:opacity-70">背景图片URLs</label>
                <Textarea
                  v-model="urlTextarea"
                  placeholder="每行输入一个图片URL，支持jpg、png、gif、webp格式&#10;例如：&#10;https://example.com/image1.jpg&#10;https://example.com/image2.png&#10;https://unsplash.com/photo/xxx"
                  class="w-full resize-none min-h-[8rem] max-h-[12rem] overflow-y-auto"
                  rows="6"
                />
                <div class="text-xs text-muted-foreground">
                  有效URL数量: {{ validUrlCount }} / 总数: {{ totalUrlCount }}
                </div>
              </div>

              <!-- Bing图片预览 -->
              <div v-if="formValues.newtabBackgroundSource === 'bing'" class="space-y-2">
                <label class="text-sm font-medium leading-none peer-disabled:cursor-not-allowed peer-disabled:opacity-70">Bing每日一图预览</label>
                <Button
                  variant="outline"
                  size="sm"
                  @click="previewBingImage"
                  :disabled="isLoadingBingImage"
                  class="w-full"
                >
                  <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="mr-2">
                    <path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z" />
                    <circle cx="12" cy="12" r="3" />
                  </svg>
                  {{ isLoadingBingImage ? '加载中...' : '预览今日Bing图片' }}
                </Button>

                <!-- Bing图片预览区域 -->
                <div v-if="bingImageUrl" class="relative">
                  <img
                    :src="bingImageUrl"
                    alt="Bing每日一图预览"
                    class="w-full h-32 object-cover rounded-md border border-border"
                  />
                  <div class="absolute bottom-2 right-2 bg-black/50 text-white text-xs px-2 py-1 rounded">
                    Bing每日一图
                  </div>
                </div>
              </div>

              <!-- 毛玻璃效果设置 -->
              <div v-if="formValues.newtabBackgroundSource !== 'blank'" class="space-y-2">
                <BlurSlider
                  v-model="formValues.newtabBlurIntensity"
                  label="毛玻璃力度"
                  :min="0"
                  :max="20"
                  :step="1"
                />
              </div>
            </div>

                        <div class="space-y-2">
              <div class="flex gap-2">
                <Button 
                  type="button" 
                  class="flex-1" 
                  :variant="hasChanges ? 'destructive' : 'default'"
                  @click="onSubmit" 
                  :disabled="isLoading || !hasChanges || isSaving"
                >
                  {{ saveButtonText }}
                </Button>
                <Button 
                  type="button" 
                  variant="outline" 
                  @click="handleReset" 
                  :disabled="isLoading || !hasChanges || isSaving"
                  class="px-3"
                >
                  重置
                </Button>
              </div>
              
              <Button 
                type="button" 
                variant="secondary" 
                @click="handleRestoreDefault" 
                :disabled="isLoading || isSaving"
                class="w-full"
              >
                <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none"
                  stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="mr-2">
                  <path d="M3 12a9 9 0 0 1 9-9 9.75 9.75 0 0 1 6.74 2.74L21 8" />
                  <path d="M21 3v5h-5" />
                  <path d="M21 12a9 9 0 0 1-9 9 9.75 9.75 0 0 1-6.74-2.74L3 16" />
                  <path d="M3 21v-5h5" />
                </svg>
                恢复默认配置
              </Button>
            </div>

          <!-- 最后同步时间 -->
          <div class="text-xs text-muted-foreground text-center">最后同步时间：{{ lastSyncText }}</div>
        </TabsContent>

        <!-- 添加书签页面 -->
        <TabsContent value="bookmark" class="p-3 space-y-4 overflow-y-auto">
          <div class="space-y-3">
            <div>
              <label class="text-sm font-medium mb-1 block">网址</label>
              <Input 
                v-model="currentTab.url" 
                placeholder="https://example.com" 
                class="w-full text-xs"
                readonly
              />
            </div>
            
            <div>
              <label class="text-sm font-medium mb-1 block">书签名称 *</label>
              <Input 
                v-model="currentTab.title" 
                placeholder="输入书签名称" 
                class="w-full"
              />
            </div>
            
            <div>
              <label class="text-sm font-medium mb-1 block">描述</label>
              <Textarea 
                v-model="currentTab.description" 
                placeholder="输入描述（可选）" 
                class="w-full resize-none max-h-[4.5rem] overflow-y-auto"
                rows="3"
              />
            </div>
            
            <div>
              <label class="text-sm font-medium mb-1 block">选择空间</label>
              <Select v-model="currentTab.namespaceId">
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

            <div>
              <label class="text-sm font-medium mb-1 block">选择标签</label>
              <MultiSelect
                v-model="currentTab.tagIds"
                :items="tags"
                placeholder="选择标签（可多选）"
                :key="multiSelectKey"
              />
            </div>
          </div>
          
          <!-- 提示信息 -->
          <Alert v-if="addBookmarkAlert.show" :variant="addBookmarkAlert.type === 'error' ? 'destructive' : 'default'">
            <AlertDescription>
              {{ addBookmarkAlert.message }}
            </AlertDescription>
          </Alert>
          
          <!-- 操作按钮 -->
          <div class="flex gap-2">
            <Button 
              class="flex-1" 
              variant="outline" 
              @click="refreshCurrentTabInfo"
              :disabled="isAddingBookmark"
            >
              <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none"
                stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="mr-2">
                <path d="M3 12a9 9 0 0 1 9-9 9.75 9.75 0 0 1 6.74 2.74L21 8" />
                <path d="M21 3v5h-5" />
                <path d="M21 12a9 9 0 0 1-9 9 9.75 9.75 0 0 1-6.74-2.74L3 16" />
                <path d="M3 21v-5h5" />
              </svg>
              刷新页面信息
            </Button>
            <Button 
              class="flex-1" 
              @click="addBookmarkToSinan" 
              :disabled="isAddingBookmark"
            >
              <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none"
                stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="mr-2">
                <path d="M12 5v14M5 12h14" />
              </svg>
              {{ isAddingBookmark ? '添加中...' : '添加书签' }}
            </Button>
          </div>
        </TabsContent>

        <!-- 系统配置页面 -->
        <TabsContent value="settings" class="p-3 space-y-4 overflow-y-auto">
          <!-- 表单区域 -->
          <div class="space-y-4">
            <!-- 服务地址 -->
            <div class="space-y-2">
              <label class="text-sm font-medium leading-none peer-disabled:cursor-not-allowed peer-disabled:opacity-70">服务地址</label>
              <Input
                v-model="formValues.webUrl"
                placeholder="请输入服务地址"
                autocomplete="off"
              />
            </div>

            <!-- API接口地址 -->
            <div class="space-y-2">
              <label class="text-sm font-medium leading-none peer-disabled:cursor-not-allowed peer-disabled:opacity-70">接口地址</label>
              <Input
                v-model="formValues.serverUrl"
                placeholder="请输入API接口地址"
                autocomplete="off"
              />
            </div>

            <!-- 接口密钥 -->
            <div class="space-y-2">
              <label class="text-sm font-medium leading-none peer-disabled:cursor-not-allowed peer-disabled:opacity-70">接口密钥</label>
              <Input 
                v-model="formValues.apiKey" 
                type="password" 
                placeholder="请输入接口密钥" 
                autocomplete="off" 
              />
            </div>

            <!-- 自动同步和同步间隔 -->
            <div class="flex items-center justify-between gap-4">
              <!-- Switch 开关自动同步书签 -->
              <div class="flex items-center gap-2 space-y-0">
                <label class="text-sm text-foreground font-medium">自动同步</label>
                <Switch
                  v-model="formValues.autoSync"
                />
              </div>

              <!-- 同步间隔时间 -->
              <div class="flex items-center gap-2 space-y-0">
                <label class="text-sm text-foreground font-medium">间隔</label>
                <Select
                  v-model="formValues.syncInterval"
                >
                  <SelectTrigger class="w-20">
                    <SelectValue placeholder="选择" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="1">1</SelectItem>
                    <SelectItem value="5">5</SelectItem>
                    <SelectItem value="10">10</SelectItem>
                    <SelectItem value="15">15</SelectItem>
                    <SelectItem value="30">30</SelectItem>
                  </SelectContent>
                </Select>
                <span class="text-xs text-muted-foreground">分钟</span>
              </div>
            </div>

            <div class="space-y-2">
              <div class="flex gap-2">
                <Button 
                  type="button" 
                  class="flex-1" 
                  :variant="hasChanges ? 'destructive' : 'default'"
                  @click="onSubmit" 
                  :disabled="isLoading || !hasChanges || isSaving"
                >
                  {{ saveButtonText }}
                </Button>
                <Button 
                  type="button" 
                  variant="outline" 
                  @click="handleReset" 
                  :disabled="isLoading || !hasChanges || isSaving"
                  class="px-3"
                >
                  重置
                </Button>
              </div>
              
              <Button 
                type="button" 
                variant="secondary" 
                @click="handleRestoreDefault" 
                :disabled="isLoading || isSaving"
                class="w-full"
              >
                <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none"
                  stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="mr-2">
                  <path d="M3 12a9 9 0 0 1 9-9 9.75 9.75 0 0 1 6.74 2.74L21 8" />
                  <path d="M21 3v5h-5" />
                  <path d="M21 12a9 9 0 0 1-9 9 9.75 9.75 0 0 1-6.74-2.74L3 16" />
                  <path d="M3 21v-5h5" />
                </svg>
                恢复默认配置
              </Button>
            </div>
          </div>
        </TabsContent>
      </Tabs>
    </div>
  </div>
</template>

<style scoped>
/* 隐藏滚动条但保持滚动功能 */
.overflow-y-auto::-webkit-scrollbar {
  display: none;
}

.overflow-y-auto {
  -ms-overflow-style: none;  /* IE and Edge */
  scrollbar-width: none;  /* Firefox */
}

/* 针对所有可能的滚动容器 */
:deep(.overflow-y-auto::-webkit-scrollbar) {
  display: none;
}

:deep(.overflow-y-auto) {
  -ms-overflow-style: none;
  scrollbar-width: none;
}

/* 针对整个标签页内容区域 */
:deep([data-radix-tabs-content]) {
  overflow-y: auto;
}

:deep([data-radix-tabs-content]::-webkit-scrollbar) {
  display: none;
}

:deep([data-radix-tabs-content]) {
  -ms-overflow-style: none;
  scrollbar-width: none;
}
</style>
