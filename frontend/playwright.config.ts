import { defineConfig, devices } from '@playwright/test'

/**
 * Playwright E2E测试配置 - 前端 UI 测试
 * 
 * @see https://playwright.dev/docs/test-configuration
 */
const baseURL = process.env.PLAYWRIGHT_BASE_URL || 'http://localhost:3000'
const webServerUrl = process.env.PLAYWRIGHT_WEB_SERVER_URL || baseURL
const webServerCommand = process.env.PLAYWRIGHT_WEB_SERVER_COMMAND || 'cd .. && docker compose up -d && sleep 10'
const disableWebServer = process.env.PLAYWRIGHT_WEB_SERVER_DISABLED === 'true'

export default defineConfig({
  // 测试目录
  testDir: './e2e',
  
  // 测试文件匹配模式
  testMatch: '**/*.spec.ts',
  
  // 并行运行测试
  fullyParallel: true,
  
  // CI环境下失败立即停止
  forbidOnly: !!process.env.CI,
  
  // 失败重试次数
  retries: process.env.CI ? 2 : 0,
  
  // 并行worker数量
  workers: process.env.CI ? 1 : undefined,
  
  // 测试报告
  reporter: [
    ['html', { outputFolder: 'playwright-report' }],
    ['list'],
    ...(process.env.CI ? [['github'] as const] : []),
  ],
  
  // 全局设置
  use: {
    // 基础URL
    baseURL,
    
    // 截图设置
    screenshot: 'only-on-failure',
    
    // 视频设置
    video: 'retain-on-failure',
    
    // 追踪设置
    trace: 'retain-on-failure',
    
    // 超时设置
    actionTimeout: 15000,
    navigationTimeout: 30000,
  },
  
  // 全局超时
  timeout: 60000,
  
  // 预期超时
  expect: {
    timeout: 10000,
  },
  
  // 项目配置（多浏览器测试）
  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
  ],
  
  // 本地开发时启动服务
  webServer: process.env.CI || disableWebServer ? undefined : {
    command: webServerCommand,
    url: webServerUrl,
    reuseExistingServer: !process.env.CI,
    timeout: 120000,
  },
})

