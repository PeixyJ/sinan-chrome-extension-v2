<script setup lang="ts">
import { computed } from 'vue'
import { Button } from "../../../../components/ui/button";
import { Input } from "../../../../components/ui/input";
import Textarea from "../../../../components/ui/textarea/Textarea.vue";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "../../../../components/ui/select";
import { Alert, AlertDescription } from "../../../../components/ui/alert";
import ImageUpload from '../../../../components/ui/image-upload/ImageUpload.vue'
import BlurSlider from '../../../../components/ui/blur-slider/BlurSlider.vue'

// Props
interface Props {
  formValues: any
  hasChanges: boolean
  isLoading: boolean
  isSaving: boolean
  saveButtonText: string
  lastSyncText: string
  isSyncing: boolean
  syncButtonText: string
  isDeleting: boolean
  deleteButtonText: string
  syncAlert: { show: boolean; type: 'success' | 'error'; message: string }
  urlTextarea: string
  totalUrlCount: number
  validUrlCount: number
  bingImageUrl: string
  isLoadingBingImage: boolean
}

const props = defineProps<Props>()

// Emits
const emit = defineEmits<{
  'update:formValues': [value: any]
  'update:urlTextarea': [value: string]
  'open-sinan': []
  'sync': []
  'delete-bookmarks': []
  'submit': []
  'reset': []
  'restore-default': []
  'preview-bing-image': []
}>()

// 计算属性双向绑定
const formValues = computed({
  get: () => props.formValues,
  set: (value) => emit('update:formValues', value)
})

const urlTextarea = computed({
  get: () => props.urlTextarea,
  set: (value) => emit('update:urlTextarea', value)
})

// 方法
const handleOpenSinan = () => emit('open-sinan')
const handleSync = () => emit('sync')
const handleDeleteBookmarks = () => emit('delete-bookmarks')
const onSubmit = () => emit('submit')
const handleReset = () => emit('reset')
const handleRestoreDefault = () => emit('restore-default')
const previewBingImage = () => emit('preview-bing-image')
</script>

<template>
  <div class="p-3 flex flex-col h-full space-y-4 overflow-y-auto">
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
        <Select v-model="formValues.newtabBackgroundSource">
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
        <Select v-model="formValues.iconSource">
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
  </div>
</template>