module.exports = {
  apps: [
    {
      name: 'mensaena',
      script: 'npx',
      args: 'next start -p 3001',
      cwd: '/home/user/webapp',
      env: {
        NODE_ENV: 'production',
        PORT: 3001,
      },
      watch: false,
      instances: 1,
      exec_mode: 'fork',
      max_memory_restart: '512M',
    },
  ],
}
