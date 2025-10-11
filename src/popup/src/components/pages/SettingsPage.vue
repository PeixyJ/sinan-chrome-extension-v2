<script setup lang="ts">
import { computed } from 'vue'
import { Button } from "../../../../components/ui/button";
import { Input } from "../../../../components/ui/input";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "../../../../components/ui/select";
import { Switch } from "../../../../components/ui/switch";

// Props
interface Props {
  formValues: any
  hasChanges: boolean
  isLoading: boolean
  isSaving: boolean
  saveButtonText: string
}

const props = defineProps<Props>()

// Emits
const emit = defineEmits<{
  'update:formValues': [value: any]
  'submit': []
  'reset': []
  'restore-default': []
}>()

// 计算属性双向绑定
const formValues = computed({
  get: () => props.formValues,
  set: (value) => emit('update:formValues', value)
})

// 方法
const onSubmit = () => emit('submit')
const handleReset = () => emit('reset')
const handleRestoreDefault = () => emit('restore-default')
</script>

<template>
  <div class="p-3 space-y-4 overflow-y-auto">
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
  </div>
</template>