@echo off
chcp 65001 >nul
echo [1/3] 清理缓存...
hexo clean

echo [2/3] 生成静态文件...
hexo generate

echo [3/3] 部署到 GitHub...
hexo deploy

echo.
echo 部署完成！访问: https://drda-x.github.io/drda-blog/
pause
