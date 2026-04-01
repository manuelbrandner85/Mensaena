module.exports = {
  apps: [
    {
      name: 'mensaena',
      script: 'npx',
      args: 'next dev -p 3001',
      cwd: '/home/user/webapp',
      env: {
        NODE_ENV: 'development',
        PORT: 3001,
        NODE_OPTIONS: '--max-old-space-size=600',
      },
      watch: false,
      instances: 1,
      exec_mode: 'fork',
      max_memory_restart: '700M',
    },
  ],
}
