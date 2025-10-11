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
import { MultiSelect } from "../../../../components/ui/multi-select";
import type { SnSpace, TagResp } from '../../../../shared/types/api'

// Props
interface Props {
  currentTab: {
    title: string
    url: string
    description: string
    namespaceId: string
    tagIds: string[]
  }
  namespaces: SnSpace[]
  tags: TagResp[]
  virtualSpaces?: SnSpace[]
  virtualTags?: TagResp[]
  isAddingBookmark: boolean
  addBookmarkAlert: { show: boolean; type: 'success' | 'error'; message: string }
  multiSelectKey: number
  isAnalyzingWebsite?: boolean
  sseDescription?: string
}

const props = defineProps<Props>()

// Emits
const emit = defineEmits<{
  'update:currentTab': [value: any]
  'refresh-current-tab-info': []
  'add-bookmark': []
  'analyze-website': []
}>()

// 计算属性双向绑定
const currentTab = computed({
  get: () => props.currentTab,
  set: (value) => emit('update:currentTab', value)
})

// 合并现有空间和虚拟空间
const allNamespaces = computed(() => {
  return [
    ...(props.namespaces || []),
    ...(props.virtualSpaces || [])
  ]
})

// 合并现有标签和虚拟标签
const allTags = computed(() => {
  return [
    ...(props.tags || []),
    ...(props.virtualTags || [])
  ]
})

// 方法
const refreshCurrentTabInfo = () => emit('refresh-current-tab-info')
const addBookmarkToSinan = () => emit('add-bookmark')
const analyzeWebsite = () => emit('analyze-website')
</script>

<style scoped>
@keyframes fade-in {
  from {
    opacity: 0;
    transform: translateY(-10px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

.animate-fade-in {
  animation: fade-in 0.3s ease-in-out;
}
</style>

<template>
  <div class="p-3 space-y-4 overflow-y-auto">
    <!-- 错误提示信息 - 只显示错误类型的Alert -->
    <Alert v-if="addBookmarkAlert.show && addBookmarkAlert.type === 'error'" variant="destructive">
      <AlertDescription>
        {{ addBookmarkAlert.message }}
      </AlertDescription>
    </Alert>

    <div class="space-y-3">
      <div>
        <label class="text-sm font-medium mb-1 block">网址 *</label>
        <div class="flex items-center gap-2">
          <Input v-model="currentTab.url" placeholder="https://example.com" class="flex-1" />
          <Button variant="outline" size="icon" class="flex-shrink-0 w-9 h-9 hover:bg-amber-100 hover:border-amber-400 hover:text-amber-700 transition-colors" @click="analyzeWebsite" :disabled="isAnalyzingWebsite">
            <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none"
              stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
              <path
                d="M11.017 2.814a1 1 0 0 1 1.966 0l1.051 5.558a2 2 0 0 0 1.594 1.594l5.558 1.051a1 1 0 0 1 0 1.966l-5.558 1.051a2 2 0 0 0-1.594 1.594l-1.051 5.558a1 1 0 0 1-1.966 0l-1.051-5.558a2 2 0 0 0-1.594-1.594l-5.558-1.051a1 1 0 0 1 0-1.966l5.558-1.051a2 2 0 0 0 1.594-1.594z" />
              <path d="M20 2v4" />
              <path d="M22 4h-4" />
              <circle cx="4" cy="20" r="2" />
            </svg>
          </Button>
        </div>
        <!-- AI分析描述显示 -->
        <div v-if="sseDescription" class="text-amber-600 text-sm mt-1 animate-fade-in">
          {{ sseDescription }}
        </div>
      </div>

      <div>
        <label class="text-sm font-medium mb-1 block">书签名称 *</label>
        <Input v-model="currentTab.title" placeholder="输入书签名称" class="w-full" />
      </div>

      <div>
        <label class="text-sm font-medium mb-1 block">描述</label>
        <Textarea v-model="currentTab.description" placeholder="输入描述（可选）"
          class="w-full resize-none max-h-[4.5rem] overflow-y-auto" rows="3" />
      </div>

      <div>
        <label class="text-sm font-medium mb-1 block">选择空间 *</label>
        <Select v-model="currentTab.namespaceId">
          <SelectTrigger class="w-full">
            <SelectValue placeholder="选择一个空间" />
          </SelectTrigger>
          <SelectContent>
            <SelectItem v-for="namespace in allNamespaces" :key="namespace.id" :value="namespace.id">
              <div class="flex items-center gap-2">
                <span class="text-color">{{ namespace.name.replace(':new', '') }}</span>
              </div>
            </SelectItem>
          </SelectContent>
        </Select>
      </div>

      <div>
        <label class="text-sm font-medium mb-1 block">选择标签</label>
        <MultiSelect v-model="currentTab.tagIds" :items="allTags" placeholder="选择标签（可多选）" :key="multiSelectKey" />
      </div>
    </div>

    <!-- 操作按钮 -->
    <div class="flex gap-2">
      <Button class="flex-1" variant="outline" @click="refreshCurrentTabInfo" :disabled="isAddingBookmark">
        <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none"
          stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="mr-2">
          <path d="M3 12a9 9 0 0 1 9-9 9.75 9.75 0 0 1 6.74 2.74L21 8" />
          <path d="M21 3v5h-5" />
          <path d="M21 12a9 9 0 0 1-9 9 9.75 9.75 0 0 1-6.74-2.74L3 16" />
          <path d="M3 21v-5h5" />
        </svg>
        刷新页面信息
      </Button>
      <Button class="flex-1" @click="addBookmarkToSinan" :disabled="isAddingBookmark">
        <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none"
          stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="mr-2">
          <path d="M12 5v14M5 12h14" />
        </svg>
        {{ isAddingBookmark ? '添加中...' : '添加书签' }}
      </Button>
    </div>
  </div>
</template>