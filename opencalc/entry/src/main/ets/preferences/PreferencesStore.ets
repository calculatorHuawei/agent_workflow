// OpenCalc — 偏好设置存储
// 移植自：MyPreferences.kt（123行）
// 封装 @ohos.data.preferences 实现键值对持久化存储

import { preferences } from '@kit.ArkData'
import { common } from '@kit.AbilityKit'
import {
  CalculatorPreferences,
  DEFAULT_PREFERENCES,
  HistoryItem,
  ScientificModeType
} from '../model/Models'

/** 偏好存储文件名 */
const PREF_NAME: string = 'opencalc_preferences'

/**
 * 偏好设置管理器
 * 封装了主题、振动、防休眠、历史记录、科学模式、
 * 弧度/角度、数字精度、分隔符等配置的读写操作。
 * 所有写操作都会立即 flush 到磁盘。
 */
export class PreferencesStore {
  private store: preferences.Preferences | null = null
  private context: common.UIAbilityContext

  constructor(context: common.UIAbilityContext) {
    this.context = context
  }

  /** 初始化偏好存储，必须在构造后调用 */
  async init(): Promise<void> {
    this.store = await preferences.getPreferences(this.context, PREF_NAME)
  }

  // ==================== 主题 ====================

  /** 获取主题索引（0=默认 1=AMOLED 2=Material） */
  async getTheme(): Promise<number> {
    if (!this.store) return DEFAULT_PREFERENCES.theme
    return await this.store.get('theme', DEFAULT_PREFERENCES.theme) as number
  }

  /** 设置主题索引 */
  async setTheme(value: number): Promise<void> {
    if (!this.store) return
    await this.store.put('theme', value)
    await this.store.flush()
  }

  /** 获取强制日夜模式 */
  async getForceDayNight(): Promise<number> {
    if (!this.store) return DEFAULT_PREFERENCES.forceDayNight
    return await this.store.get('forceDayNight', DEFAULT_PREFERENCES.forceDayNight) as number
  }

  /** 设置强制日夜模式 */
  async setForceDayNight(value: number): Promise<void> {
    if (!this.store) return
    await this.store.put('forceDayNight', value)
    await this.store.flush()
  }

  // ==================== 振动 ====================

  /** 获取振动反馈开关状态 */
  async getVibrationEnabled(): Promise<boolean> {
    if (!this.store) return DEFAULT_PREFERENCES.vibrationEnabled
    return await this.store.get('vibrationEnabled', DEFAULT_PREFERENCES.vibrationEnabled) as boolean
  }

  /** 设置振动反馈开关 */
  async setVibrationEnabled(value: boolean): Promise<void> {
    if (!this.store) return
    await this.store.put('vibrationEnabled', value)
    await this.store.flush()
  }

  // ==================== 防休眠 ====================

  /** 获取防休眠开关状态 */
  async getPreventSleep(): Promise<boolean> {
    if (!this.store) return DEFAULT_PREFERENCES.preventSleep
    return await this.store.get('preventSleep', DEFAULT_PREFERENCES.preventSleep) as boolean
  }

  /** 设置防休眠开关 */
  async setPreventSleep(value: boolean): Promise<void> {
    if (!this.store) return
    await this.store.put('preventSleep', value)
    await this.store.flush()
  }

  // ==================== 历史记录 ====================

  /** 获取历史记录最大保存条数 */
  async getHistorySize(): Promise<number> {
    if (!this.store) return DEFAULT_PREFERENCES.historySize
    return await this.store.get('historySize', DEFAULT_PREFERENCES.historySize) as number
  }

  /** 设置历史记录最大条数 */
  async setHistorySize(value: number): Promise<void> {
    if (!this.store) return
    await this.store.put('historySize', value)
    await this.store.flush()
  }

  /**
   * 获取历史记录列表
   * 从 preferences 中读取 JSON 字符串并反序列化
   */
  async getHistory(): Promise<HistoryItem[]> {
    if (!this.store) return []
    const json: string = await this.store.get('history', '[]') as string
    try {
      return JSON.parse(json) as HistoryItem[]
    } catch (_e) {
      return []  // JSON 损坏时返回空数组
    }
  }

  /**
   * 保存历史记录列表
   * 自动按最大条数裁剪，序列化为 JSON 后存储
   */
  async setHistory(items: HistoryItem[]): Promise<void> {
    if (!this.store) return
    const maxSize: number = await this.getHistorySize()
    const trimmed: HistoryItem[] = items.slice(0, maxSize)
    await this.store.put('history', JSON.stringify(trimmed))
    await this.store.flush()
  }

  // ==================== 科学模式 ====================

  /** 获取默认科学模式状态 */
  async getScientificModeDefault(): Promise<number> {
    if (!this.store) return DEFAULT_PREFERENCES.scientificModeDefault
    return await this.store.get('scientificModeDefault', DEFAULT_PREFERENCES.scientificModeDefault) as number
  }

  /** 设置默认科学模式 */
  async setScientificModeDefault(value: number): Promise<void> {
    if (!this.store) return
    await this.store.put('scientificModeDefault', value)
    await this.store.flush()
  }

  // ==================== 弧度/角度 ====================

  /** 获取默认弧度模式 */
  async getRadiansDefault(): Promise<boolean> {
    if (!this.store) return DEFAULT_PREFERENCES.radiansDefault
    return await this.store.get('radiansDefault', DEFAULT_PREFERENCES.radiansDefault) as boolean
  }

  /** 设置默认弧度模式 */
  async setRadiansDefault(value: boolean): Promise<void> {
    if (!this.store) return
    await this.store.put('radiansDefault', value)
    await this.store.flush()
  }

  // ==================== 数字精度 ====================

  /** 获取数字精度 */
  async getNumberPrecision(): Promise<number> {
    if (!this.store) return DEFAULT_PREFERENCES.numberPrecision
    return await this.store.get('numberPrecision', DEFAULT_PREFERENCES.numberPrecision) as number
  }

  /** 设置数字精度 */
  async setNumberPrecision(value: number): Promise<void> {
    if (!this.store) return
    await this.store.put('numberPrecision', value)
    await this.store.flush()
  }

  // ==================== 分隔符 ====================

  /** 获取小数点符号 */
  async getDecimalSeparator(): Promise<string> {
    if (!this.store) return DEFAULT_PREFERENCES.decimalSeparatorSymbol
    return await this.store.get('decimalSeparator', DEFAULT_PREFERENCES.decimalSeparatorSymbol) as string
  }

  /** 设置小数点符号 */
  async setDecimalSeparator(value: string): Promise<void> {
    if (!this.store) return
    await this.store.put('decimalSeparator', value)
    await this.store.flush()
  }

  /** 获取千分位符号 */
  async getGroupingSeparator(): Promise<string> {
    if (!this.store) return DEFAULT_PREFERENCES.groupingSeparatorSymbol
    return await this.store.get('groupingSeparator', DEFAULT_PREFERENCES.groupingSeparatorSymbol) as string
  }

  /** 设置千分位符号 */
  async setGroupingSeparator(value: string): Promise<void> {
    if (!this.store) return
    await this.store.put('groupingSeparator', value)
    await this.store.flush()
  }

  // ==================== 批量读取 ====================

  /** 一次性读取所有偏好设置 */
  async getAllPreferences(): Promise<CalculatorPreferences> {
    return {
      theme: await this.getTheme(),
      forceDayNight: await this.getForceDayNight(),
      vibrationEnabled: await this.getVibrationEnabled(),
      preventSleep: await this.getPreventSleep(),
      historySize: await this.getHistorySize(),
      scientificModeDefault: await this.getScientificModeDefault(),
      radiansDefault: await this.getRadiansDefault(),
      numberPrecision: await this.getNumberPrecision(),
      decimalSeparatorSymbol: await this.getDecimalSeparator(),
      groupingSeparatorSymbol: await this.getGroupingSeparator()
    }
  }
}
