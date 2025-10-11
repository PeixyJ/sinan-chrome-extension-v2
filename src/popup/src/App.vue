<script setup lang="ts">
import { Button } from "@/components/ui/button";
import { useColorMode } from '@vueuse/core'
import { onMounted, onUnmounted, ref, computed, watch, nextTick } from 'vue'
import { StorageService } from '../../shared/services/storage'
import { SinanApiService } from '../../shared/services/api'
import { BookmarkService } from '../../shared/services/bookmark'
import { IconCacheService } from '../../shared/services/iconCache'
import { NewtabBackgroundService } from '../../shared/services/tagBackground'
import type { SnSpace, TagResp, NewSpace, NewTag } from '../../shared/types/api'
import Tabs from "@/components/ui/tabs/Tabs.vue";
import TabsList from "@/components/ui/tabs/TabsList.vue";
import TabsTrigger from "@/components/ui/tabs/TabsTrigger.vue";
import TabsContent from "@/components/ui/tabs/TabsContent.vue";
import BasicFeaturesPage from './components/pages/BasicFeaturesPage.vue'
import AddBookmarkPage from './components/pages/AddBookmarkPage.vue'
import SettingsPage from './components/pages/SettingsPage.vue'

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
const isAnalyzingWebsite = ref(false)
const sseDescription = ref('')
const namespaces = ref<SnSpace[]>([])
const tags = ref<TagResp[]>([])
const virtualSpaces = ref<SnSpace[]>([])
const virtualTags = ref<TagResp[]>([])
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
    // 检查是否选择了虚拟空间
    let newSpace: NewSpace | undefined
    let actualNamespaceId: string | undefined = currentTab.value.namespaceId

    const selectedVirtualSpace = virtualSpaces.value.find(vs => vs.id === currentTab.value.namespaceId)
    if (selectedVirtualSpace) {
      newSpace = {
        name: selectedVirtualSpace.name,
        description: '',
        icon: ''
      }
      actualNamespaceId = undefined // 虚拟空间不设置namespaceId
    }

    // 检查是否选择了虚拟标签
    const newTags: NewTag[] = []
    const actualTagIds: string[] = []

    currentTab.value.tagIds.forEach(tagId => {
      const virtualTag = virtualTags.value.find(vt => vt.id === tagId)
      if (virtualTag) {
        newTags.push({
          name: virtualTag.name,
          color: virtualTag.color,
          description: ''
        })
      } else {
        actualTagIds.push(tagId)
      }
    })

    const response = await SinanApiService.addBookmark({
      name: currentTab.value.title.trim(),
      url: currentTab.value.url.trim(),
      description: currentTab.value.description.trim() || undefined,
      namespaceId: actualNamespaceId || undefined,
      tagsIds: actualTagIds.length > 0 ? actualTagIds : undefined,
      newSpace: newSpace,
      newTags: newTags.length > 0 ? newTags : undefined
    })

    if (response.code === 0) {
      console.log('书签添加成功:', response.data)

      // 清空虚拟空间和标签
      virtualSpaces.value = []
      virtualTags.value = []

      // 重新加载空间和标签数据
      await Promise.all([loadNamespaces(), loadTags()])

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

// AI分析网站
const analyzeWebsite = async () => {
  if (!currentTab.value.url.trim()) {
    addBookmarkAlert.value = {
      show: true,
      type: 'error',
      message: '请先获取当前页面信息'
    }
    return
  }

  // 清空之前的SSE描述
  sseDescription.value = ''

  isAnalyzingWebsite.value = true

  try {
    const config = await StorageService.getConfig()
    const serverUrl = config.serverUrl?.replace(/\/$/, '') || 'https://sinan.host/api'
    const accessKey = config.apiKey

    if (!accessKey) {
      throw new Error('请先配置API密钥')
    }

    const analyzeUrl = `${serverUrl}/api/analyze-website?url=${encodeURIComponent(currentTab.value.url)}&accessKey=${encodeURIComponent(accessKey)}`

    console.log('开始AI分析网站:', currentTab.value.url)

    // 创建EventSource连接
    const eventSource = new EventSource(analyzeUrl)

    eventSource.addEventListener('status', (event) => {
      console.log('AI分析状态:', event.data)
      const basicInfo = JSON.parse(event.data)
      if (basicInfo && typeof basicInfo === 'object') {
        sseDescription.value = basicInfo.message || ''
      }
    })

    eventSource.addEventListener('basic_info', (event) => {
      console.log('AI分析基本信息:', event.data)

      // 解析basic_info数据并显示message
      try {
        const basicInfo = JSON.parse(event.data)
        if (basicInfo.message && typeof basicInfo.message === 'string') {
          sseDescription.value = basicInfo.message
        }
      } catch (error) {
        // 如果不是JSON格式，直接显示文本
        if (event.data && typeof event.data === 'string') {
          sseDescription.value = event.data
        }
      }
    })

    eventSource.addEventListener('result', (event) => {
      try {
        const result = JSON.parse(event.data)
        console.log('AI分析结果:', result)

        // 清空之前的虚拟空间和标签
        virtualSpaces.value = []
        virtualTags.value = []

        // 处理返回的Spaces - 更新到空间选择中
        if (result.data?.spaces) {
          const spaceData = result.data.spaces

          // 检查是否包含:new标记，如果是则创建虚拟空间
          if (spaceData.includes(':new')) {
            const virtualSpace: SnSpace = {
              id: spaceData, // 使用完整字符串作为ID
              userId: '',
              name: spaceData,
              pinyin: '',
              abbreviation: '',
              icon: '',
              sort: 0,
              share: false,
              shareKey: '',
              description: '',
              createTime: new Date().toISOString(),
              updateTime: new Date().toISOString(),
              deleted: 0
            }
            virtualSpaces.value.push(virtualSpace)
            currentTab.value.namespaceId = virtualSpace.id
            console.log('AI推荐新空间:', spaceData)
          } else {
            // 查找已存在的空间
            const matchedSpace = namespaces.value.find(ns =>
              ns.name === spaceData || ns.id === spaceData
            )

            if (matchedSpace) {
              currentTab.value.namespaceId = matchedSpace.id
              console.log('AI推荐现有空间:', matchedSpace.name)
            }
          }
        }

        // 处理返回的Tags - 更新到标签选择中
        if (result.data?.tags && Array.isArray(result.data.tags)) {
          const recommendedTagIds: string[] = []

          result.data.tags.forEach((tagStr: string) => {
            // 解析标签格式，例如: "JSON工具:new:#4B0082"
            const parts = tagStr.split(':')
            const tagName = parts[0]
            const isNew = parts[1] === 'new'
            const color = parts[2] || '#6B7280'

            if (isNew) {
              // 创建虚拟标签
              const virtualTag: TagResp = {
                id: tagStr, // 使用完整字符串作为ID
                name: tagName,
                color: color,
                sort: 0,
                description: '',
                createTime: new Date().toISOString(),
                updateTime: new Date().toISOString()
              }
              virtualTags.value.push(virtualTag)
              recommendedTagIds.push(virtualTag.id)
              console.log('AI推荐新标签:', tagName, '颜色:', color)
            } else {
              // 查找已存在的标签
              const matchedTag = tags.value.find(t =>
                t.name === tagName || t.id === tagStr
              )

              if (matchedTag) {
                recommendedTagIds.push(matchedTag.id)
              }
            }
          })

          if (recommendedTagIds.length > 0) {
            // 更新标签选择，保留已有的标签并添加推荐的标签
            const existingTagIds = [...currentTab.value.tagIds]
            recommendedTagIds.forEach(tagId => {
              if (!existingTagIds.includes(tagId)) {
                existingTagIds.push(tagId)
              }
            })
            currentTab.value.tagIds = existingTagIds

            // 强制更新MultiSelect组件
            multiSelectKey.value++

            console.log('AI推荐标签ID:', recommendedTagIds)
          }
        }

        // 如果有推荐的书签名称，更新标题
        if (result.data?.name && typeof result.data.name === 'string') {
          currentTab.value.title = result.data.name
          console.log('AI推荐标题:', result.data.name)
        }

        // 如果有推荐的描述，更新描述
        if (result.data?.description && typeof result.data.description === 'string') {
          currentTab.value.description = result.data.description
          console.log('AI推荐描述:', result.data.description)
        }

        // 使用SSE描述显示AI分析完成信息
        if (result.data?.message && typeof result.data.message === 'string') {
          sseDescription.value = result.data.message
        } else {
          sseDescription.value = 'AI分析完成！已为您推荐合适的空间和标签'
        }

        // 5秒后清空SSE描述
        setTimeout(() => {
          sseDescription.value = ''
        }, 5000)

      } catch (error) {
        console.error('解析AI分析结果失败:', error)
        addBookmarkAlert.value = {
          show: true,
          type: 'error',
          message: 'AI分析结果解析失败'
        }

        // 清空SSE描述
        sseDescription.value = ''
      }

      // 收到结果后关闭连接
      eventSource.close()
    })

    eventSource.addEventListener('error', (event) => {
      console.error('AI分析错误:', event)

      addBookmarkAlert.value = {
        show: true,
        type: 'error',
        message: 'AI分析失败，请稍后重试'
      }

      // 清空SSE描述
      sseDescription.value = ''

      eventSource.close()
    })

    // 设置超时
    setTimeout(() => {
      if (eventSource.readyState !== EventSource.CLOSED) {
        eventSource.close()
        addBookmarkAlert.value = {
          show: true,
          type: 'error',
          message: 'AI分析超时，请稍后重试'
        }
      }
    }, 30000) // 30秒超时

  } catch (error) {
    console.error('AI分析失败:', error)
    addBookmarkAlert.value = {
      show: true,
      type: 'error',
      message: `AI分析失败: ${error instanceof Error ? error.message : String(error)}`
    }
  } finally {
    isAnalyzingWebsite.value = false
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
        <TabsContent value="main" class="flex-1 overflow-hidden">
          <BasicFeaturesPage
            :form-values="formValues"
            :has-changes="hasChanges"
            :is-loading="isLoading"
            :is-saving="isSaving"
            :save-button-text="saveButtonText"
            :last-sync-text="lastSyncText"
            :is-syncing="isSyncing"
            :sync-button-text="syncButtonText"
            :is-deleting="isDeleting"
            :delete-button-text="deleteButtonText"
            :sync-alert="syncAlert"
            :url-textarea="urlTextarea"
            :total-url-count="totalUrlCount"
            :valid-url-count="validUrlCount"
            :bing-image-url="bingImageUrl"
            :is-loading-bing-image="isLoadingBingImage"
            @update:formValues="formValues = $event"
            @update:urlTextarea="urlTextarea = $event"
            @open-sinan="handleOpenSinan"
            @sync="handleSync"
            @delete-bookmarks="handleDeleteBookmarks"
            @submit="onSubmit"
            @reset="handleReset"
            @restore-default="handleRestoreDefault"
            @preview-bing-image="previewBingImage"
          />
        </TabsContent>

        <!-- 添加书签页面 -->
        <TabsContent value="bookmark" class="flex-1 overflow-hidden">
          <AddBookmarkPage
            :current-tab="currentTab"
            :namespaces="namespaces"
            :tags="tags"
            :virtual-spaces="virtualSpaces"
            :virtual-tags="virtualTags"
            :is-adding-bookmark="isAddingBookmark"
            :is-analyzing-website="isAnalyzingWebsite"
            :sse-description="sseDescription"
            :add-bookmark-alert="addBookmarkAlert"
            :multi-select-key="multiSelectKey"
            @update:currentTab="currentTab = $event"
            @refresh-current-tab-info="refreshCurrentTabInfo"
            @add-bookmark="addBookmarkToSinan"
            @analyze-website="analyzeWebsite"
          />
        </TabsContent>

        <!-- 系统配置页面 -->
        <TabsContent value="settings" class="flex-1 overflow-hidden">
          <SettingsPage
            :form-values="formValues"
            :has-changes="hasChanges"
            :is-loading="isLoading"
            :is-saving="isSaving"
            :save-button-text="saveButtonText"
            @update:formValues="formValues = $event"
            @submit="onSubmit"
            @reset="handleReset"
            @restore-default="handleRestoreDefault"
          />
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
