---
title: 鱼排Excel聊天室 · 更新公告
date: 2026-11-19 10:49:47
tags: [油猴, js, 浏览器]
categories: [笔记]
top_img: "https://img.8845.top/img2/130471028_p0.jpg"
cover: "https://img.8845.top/img2/130471028_p0.jpg"
author: drda
---
新平台，新气象，为了方便喜欢用excel聊天室的鱼油能好好摸鱼聊天，做了本次更新

## 一句话概述本次更新

本次更新将脚本从旧版 `fishpi` 站点 SDK 全面迁移到 **API v3**，使其可运行在 **新版站点 https://new.fishpi.cn/** 上，并修复了迁移过程中发现的一系列问题。

> 只能说，能用了！！！！！！
## 安装

目前支持手动安装：复制源码全文 → 油猴插件新建脚本 → 粘贴保存 → 打开新版鱼排（new.fishpi.cn）刷新即可
---
## 全部源码
```
// ==UserScript==
// @name         鱼排Excel聊天室
// @namespace    https://fishpi.cn
// @license      MIT
// @version      1.2.2
// @description  聊天室Excel 风格小窗
// @author       drda
// @match        https://new.fishpi.cn/*
// @icon         https://file.fishpi.cn/2025/04/9efb7eec434478a22decde86c65e6460-db4267b2.gif
// @grant        GM_addStyle
// @grant        GM_getValue
// @grant        GM_setValue
// @run-at       document-end
// ==/UserScript==

// 2026/08/04 fix:修复回复通知消息不显示
// 2026/08/04 fix:修复评论通知消息不显示
// 2026/08/05 feat:新增浮动按钮入口，可拖动，以及位置记忆
// 2026/08/05 feat:新增长按消息或右击消息弹出菜单，快捷复读消息、艾特鱼油
// 2026/09/05 feat:新增文章阅读评论
// 2026/10/09 fix:修复已知的问题
// 2026/11/18 fix:适配 API v3 接口（消息发送、文章/长篇列表、评论、图片上传）
// 2026/11/18 feat:移除 fishpi SDK 依赖，聊天室/通知/私信/红包/文章/表情全部改用 API v3
// 2026/11/19 fix:不再自行调用 /auth/refresh 换取令牌，避免轮换登录 Cookie 导致站点登录失效
// 2026/11/19 fix:401 修复——复用站点自身 accessToken（从页面 Pinia 实例读取），不自行刷新令牌

(function () {
    'use strict';

    // ── 捕获站点自身 accessToken（绝不自行调用 /auth/refresh，避免轮换登录 Cookie）──
    let siteAccessToken = null;

    // 从页面 Vue/Pinia 实例读取站点当前 accessToken
    function readSiteAccessToken() {
        try {
            const uw = (typeof unsafeWindow !== 'undefined') ? unsafeWindow : null;
            const doc = (uw && uw.document) ? uw.document : document;
            const appEl = doc.getElementById('app');
            const app = appEl && appEl.__vue_app__;
            if (!app) return null;
            const pinia = app.config && app.config.globalProperties && app.config.globalProperties.$pinia;
            if (!pinia || !pinia.state) return null;
            const state = pinia.state.value;
            if (!state) return null;
            const auth = state.auth || state['auth'];
            if (auth && typeof auth.accessToken === 'string' && auth.accessToken) return auth.accessToken;
            return null;
        } catch (e) {
            return null;
        }
    }

    function getSiteAccessToken() {
        return readSiteAccessToken() || siteAccessToken || null;
    }

    // 监听站点自身的 v3 请求，顺带同步 accessToken（用于后续刷新）
    try {
        const _origFetch = window.fetch.bind(window);
        window.fetch = function (input, init) {
            try {
                const url = typeof input === 'string' ? input : (input && input.url ? input.url : '');
                if (url.indexOf('fishpi.cn/api/v3') !== -1 && url.indexOf('/uploads/tickets') === -1) {
                    const h = init && init.headers;
                    let auth = null;
                    if (h) {
                        if (typeof h.get === 'function') {
                            auth = h.get('Authorization');
                        } else if (Array.isArray(h)) {
                            for (let i = 0; i < h.length; i++) {
                                if (String(h[i][0]).toLowerCase() === 'authorization') { auth = h[i][1]; break; }
                            }
                        } else {
                            auth = h['Authorization'] || h['authorization'];
                        }
                    }
                    if (auth && String(auth).indexOf('Bearer ') === 0) siteAccessToken = String(auth).slice(7);
                }
            } catch (e) { }
            return _origFetch.apply(this, arguments);
        };
    } catch (e) { }

    // 站点旧 SDK（含 cloudStorage）在新版页面不可用，降级为 GM 存储
    var cloudStorage = (typeof window !== 'undefined' && window.cloudStorage) || {
        getItem: async function (key) {
            try { return GM_getValue(key, null); } catch (e) { return null; }
        },
        setItem: async function (key, value) {
            try { GM_setValue(key, value); } catch (e) { }
        }
    };

    let accountInfo = null; // 当前登录用户信息
    let messages = []; // 聊天室消息列表
    let isPanelOpen = false; // 面板是否打开
    let isFull = false; /// 是否全屏
    let isPaused = false; // 是否暂停
    let autoScroll = true;// 是否自动滚动
    let isPacketOpen = false;
    let isArticleMode = false; // 是否处于文章列表模式
    let redPacketMap = {}; // 存储红包数据，用于状态更新
    let defaultEmojis = {} // 默认表情包
    let legacyEmojis = [] // 自定义表情包
    let emojiGroups = []; // 表情分组
    let groupEmojiList = []; // 分组表情
    let currentGroupIndex = 0; // 当前选中的分组索引
    let shortcutsConfig = [] // 快捷语配置
    let randomRpsConfig = { enabled: false, minMoney: 256 } // 猜拳配置
    let noticeUnreadCnt = 0;//未读总通知数
    let unreadPreMgsList = [];//私信未读列表
    let allPreMgsList = [];//全部私信列表
    let chatUnreadList = [];//过滤后的未读私信列表（用于展示）
    let unreadNoticeTypeList = []; //各个类型未读通知列表
    // 聊天室消息列表映射
    const noticeTypeDisplayMap = {
        'at': { label: '艾特我的', icon: '@' },
        'commented': { label: '评论', icon: '💬' },
        'reply': { label: '回复', icon: '↩' },
        'point': { label: '积分通知', icon: '⭐' },
        'following': { label: '新关注者', icon: '👤' },
        'sys-announce': { label: '系统通知', icon: '📢' },
        'broadcast': { label: '同城广播', icon: '📍' },
    };
    // 各通知类型未读数量
    let noticeUnReadResult = {
        unreadReplyNotificationCnt: 0,//未读回复通知数
        unreadPointNotificationCnt: 0,//未读积分通知数
        unreadAtNotificationCnt: 0,//未读 @ 通知数
        unreadBroadcastNotificationCnt: 0,//未读同城通知数
        unreadSysAnnounceNotificationCnt: 0,//未读系统通知数
        unreadNewFollowerNotificationCnt: 0,//未读关注者通知数
        unreadFollowingNotificationCnt: 0,//未读关注通知数
        unreadCommentedNotificationCnt: 0,//未读评论通知数
    }
    // 红包类型
    let redPacketTypeCn = {
        random: '拼手气',
        average: '平分',
        specify: '专属',
        heartbeat: '心跳',
        rockPaperScissors: '猜拳',
    };
    // 红包图标
    let redPacketEmoji = {
        random: '🎲',
        average: '💰',
        specify: '🎯',
        heartbeat: '💓',
        rockPaperScissors: '✊',
    };
    // 猜拳类型
    let rockPaperScissorsType = {
        rock: { value: 0, cn: '石头' },
        paper: { value: 1, cn: '剪刀' },
        scissors: { value: 2, cn: '布' }
    };
    // 默认表情别名 → Unicode 表情（v3 只提供别名，无图片 URL，用于面板展示）
    const defaultEmojiChars = {
        smile: "😄",
        laughing: "😆",
        smirk: "😏",
        heart_eyes: "😍",
        kissing_heart: "😘",
        flushed: "😳",
        grin: "😁",
        stuck_out_tongue_closed_eyes: "😝",
        kissing: "😗",
        sleeping: "😴",
        anguished: "😧",
        open_mouth: "😮",
        expressionless: "😑",
        unamused: "😒",
        sweat_smile: "😅",
        weary: "😩",
        sob: "😭",
        joy: "😂",
        astonished: "😲",
        scream: "😱",
        tired_face: "😫",
        rage: "😡",
        triumph: "😤",
        yum: "😋",
        mask: "😷",
        sunglasses: "😎",
        dizzy_face: "😵",
        imp: "👿",
        smiling_imp: "😈",
        innocent: "😇",
        alien: "👽",
        yellow_heart: "💛",
        blue_heart: "💙",
        purple_heart: "💜",
        heart: "❤️",
        green_heart: "💚",
        broken_heart: "💔",
        dizzy: "💫",
        anger: "💢",
        exclamation: "❗",
        question: "❓",
        zzz: "💤",
        notes: "🎶",
        poop: "💩",
        "+1": "👍",
        "-1": "👎",
        ok_hand: "👌",
        punch: "👊",
        v: "✌️",
        hand: "✋",
        point_up: "☝️",
        point_down: "👇",
        pray: "🙏",
        clap: "👏",
        muscle: "💪",
        ok_woman: "🙆‍♀️",
        no_good: "🙅‍♀️",
        raising_hand: "🙋‍♀️",
        massage: "💆‍♀️",
        haircut: "💇‍♀️",
        nail_care: "💅",
        see_no_evil: "🙈",
        feet: "🐾",
        kiss: "💋",
        eyes: "👀",
        trollface: "",
        snowman: "☃️",
        zap: "⚡",
        cat: "🐱",
        dog: "🐶",
        mouse: "🐭",
        hamster: "🐹",
        rabbit: "🐰",
        frog: "🐸",
        koala: "🐨",
        pig: "🐷",
        monkey: "🐵",
        racehorse: "🐎",
        camel: "🐫",
        sheep: "🐑",
        // 第五组
        elephant: "🐘",
        panda_face: "🐼",
        snake: "🐍",
        hatched_chick: "🐥",
        hatching_chick: "🐤",
        turtle: "🐢",
        bug: "🐛",
        honeybee: "🐝",
        beetle: "🐞",
        snail: "🐌",
        octopus: "🐙",
        whale: "🐳",
        dolphin: "🐬",
        dragon: "🐉",
        goat: "🐐",
        paw_prints: "🐾",
        tulip: "🌷",
        four_leaf_clover: "🍀",
        rose: "🌹",
        mushroom: "🍄",

        // 第六组
        seedling: "🌱",
        shell: "🐚",
        crescent_moon: "🌙",
        partly_sunny: "⛅",
        octocat: "", // GitHub 自定义表情，无 Unicode 字符
        jack_o_lantern: "🎃",
        ghost: "👻",
        santa: "🎅",
        tada: "🎉",
        camera: "📷",
        loudspeaker: "📢",
        hourglass: "⌛",
        lock: "🔒",
        key: "🔑",
        bulb: "💡",
        hammer: "🔨",
        moneybag: "💰",
        smoking: "🚬",
        bomb: "💣",
        gun: "🔫",

        // 第七组
        hocho: "🔪",
        pill: "💊",
        syringe: "💉",
        scissors: "✂️",
        swimmer: "🏊‍♀️",
        black_joker: "🃏",
        coffee: "☕",
        tea: "🍵",
        sake: "🍶",
        beer: "🍺",
        wine_glass: "🍷",
        pizza: "🍕",
        hamburger: "🍔",
        poultry_leg: "🍗",
        meat_on_bone: "🍖",
        dango: "🍡",
        doughnut: "🍩",
        icecream: "🍦",
        shaved_ice: "🍧",
        cake: "🎂",

        // 第八组
        cookie: "🍪",
        lollipop: "🍭",
        apple: "🍎",
        green_apple: "🍏",
        tangerine: "🍊",
        lemon: "🍋",
        cherries: "🍒",
        grapes: "🍇",
        watermelon: "🍉",
        strawberry: "🍓",
        peach: "🍑",
        melon: "🍈",
        banana: "🍌",
        pear: "🍐",
        pineapple: "🍍",
        sweet_potato: "🍠",
        eggplant: "🍆",
        tomato: "🍅"
    };
    // 默认快捷语配置
    let defaultShortcutsConfig = [
        { title: "打劫", value: "冰冰 去打劫" },
        { title: "行行好", value: "鸽 行行好吧" },
        { title: "来个红包", value: "冰冰 来个红包" },
    ]
    // 默认快捷键配置
    let defaultHotkeys = {
        toggleSmall: { ctrl: true, alt: true, key: 'm' },  // Ctrl+Alt+M 显示/隐藏小框
    }

    // ── v3 API 工具 ──
    // 生成幂等键（Idempotency-Key）：1–128 位字母、数字或 . _ : -
    function genIdempotencyKey(prefix) {
        const rnd = (typeof crypto !== 'undefined' && crypto.randomUUID)
        ? crypto.randomUUID()
        : Date.now().toString(36) + Math.random().toString(36).slice(2, 10);
        return (prefix || 'drda') + '-' + rnd;
    }

    // 毫秒时间戳转本地可读时间
    function formatDateTime(ms) {
        if (!ms) return '';
        const d = new Date(Number(ms));
        if (isNaN(d.getTime())) return '';
        const p = n => (n < 10 ? '0' + n : '' + n);
        return d.getFullYear() + '-' + p(d.getMonth() + 1) + '-' + p(d.getDate()) + ' ' + p(d.getHours()) + ':' + p(d.getMinutes());
    }

    // v3 文件上传：获取上传票据 → 使用票据直传图床，返回图片 URL 数组
    async function uploadV3Images(files) {
        const fileArr = Array.from(files);
        if (!fileArr.length) return [];
        // 1. 获取上传票据（需要 uploads.write，使用 Bearer 访问令牌）
        const ticketData = await v3Fetch('/uploads/tickets', { method: 'POST', body: '{}' });
        const ticket = ticketData.ticket;
        const tokenType = ticketData.tokenType || 'Bearer';
        const uploadURL = ticketData.uploadURL;
        const fieldName = ticketData.fieldName || 'file';
        if (!ticket || !uploadURL) throw new Error('上传票据异常');
        // 2. 使用票据直传文件
        const formData = new FormData();
        fileArr.forEach(file => {
            formData.append(fieldName, file, file.name || ('image-' + Date.now() + '.png'));
        });
        const uploadResp = await fetch(uploadURL, {
            method: 'POST',
            headers: { 'Authorization': tokenType + ' ' + ticket },
            body: formData,
            credentials: 'omit'
        });
        const uploadResult = await uploadResp.json();
        if (!uploadResult || uploadResult.code !== 0 || !uploadResult.data) {
            throw new Error((uploadResult && uploadResult.msg) || '上传失败');
        }
        const succMap = uploadResult.data.succMap || {};
        const urls = Object.values(succMap);
        const errFiles = uploadResult.data.errFiles || [];
        if (!urls.length && errFiles.length) {
            throw new Error('上传失败: ' + errFiles.join(', '));
        }
        return urls;
    }

    // ── v3 请求层 ──
    // 复用站点自身的 accessToken（不自行 /auth/refresh，避免轮换登录 Cookie）。
    const V3_BASE = 'https://fishpi.cn/api/v3';
    let siteTokenPromise = null;

    // 等待站点 accessToken 就绪（最多 8 秒）
    function ensureSiteToken() {
        const cached = getSiteAccessToken();
        if (cached) return Promise.resolve(cached);
        if (siteTokenPromise) return siteTokenPromise;
        siteTokenPromise = new Promise((resolve) => {
            const start = Date.now();
            const timer = setInterval(() => {
                const t = getSiteAccessToken();
                if (t) {
                    clearInterval(timer);
                    resolve(t);
                } else if (Date.now() - start > 8000) {
                    clearInterval(timer);
                    resolve(null);
                }
            }, 100);
        }).finally(() => { siteTokenPromise = null; });
        return siteTokenPromise;
    }

    // 统一 v3 请求：携带站点 accessToken
    async function v3Fetch(path, opts) {
        opts = opts || {};
        const doFetch = async (token) => {
            const headers = Object.assign({}, opts.headers || {});
            if (token) headers['Authorization'] = 'Bearer ' + token;
            if (opts.body != null && !headers['Content-Type']) headers['Content-Type'] = 'application/json';
            const resp = await fetch(V3_BASE + path, {
                method: opts.method || 'GET',
                headers: headers,
                body: opts.body,
                credentials: 'include'
            });
            let json = null;
            try { json = await resp.json(); } catch (e) { json = null; }
            return { resp, json };
        };

        let token = await ensureSiteToken();
        let r = await doFetch(token);
        // 站点令牌可能刚被站点自身刷新导致 401，稍候重读一次再试
        if (r.resp.status === 401 && !opts._retried) {
            siteTokenPromise = null;
            await new Promise(res => setTimeout(res, 1500));
            token = await ensureSiteToken();
            opts._retried = true;
            r = await doFetch(token);
        }
        if (!r.json || r.json.code !== 0) {
            const err = new Error((r.json && r.json.msg) || ('HTTP ' + r.resp.status));
            err.status = r.resp.status;
            err.code = r.json && r.json.code;
            if (r.resp.status === 401) {
                err.message = '登录状态已失效，请刷新页面后重试';
            }
            throw err;
        }
        return r.json.data;
    }

    // 连接 v3 实时通道（聊天室/通知/私信共用 /api/v3/realtime）
    function connectV3Realtime(ticketData, onMessage, onReady) {
        const path = ticketData.path || '/api/v3/realtime';
        const wsUrl = (location.protocol === 'https:' ? 'wss://' : 'ws://') + 'fishpi.cn' + path;
        const socket = new WebSocket(wsUrl);
        let heartbeat = null;
        socket.addEventListener('close', () => { if (heartbeat) clearInterval(heartbeat); });
        socket.addEventListener('message', (ev) => {
            let msg;
            try { msg = JSON.parse(ev.data); } catch (e) { return; }
            if (msg.type === 'authentication.required') {
                socket.send(JSON.stringify({ type: 'authenticate', ticket: ticketData.ticket }));
            } else if (msg.type === 'ready') {
                if (heartbeat) clearInterval(heartbeat);
                heartbeat = setInterval(() => {
                    if (socket.readyState === WebSocket.OPEN) socket.send(JSON.stringify({ type: 'ping' }));
                }, 25000);
                if (onReady) onReady();
            } else if (msg.type !== 'pong') {
                onMessage(msg);
            }
        });
        return socket;
    }

    // v3 聊天室消息 → 内部消息结构（兼容 parseMessage）
    function mapChatMessage(msg) {
        const author = msg.author || {};
        const card = msg.card || {};
        let content, md;
        if (msg.type === 'redPacket') {
            content = {
                type: card.type || 'unknown',
                msg: card.message || '',
                money: card.money || 0,
                count: card.count || 0,
                got: card.got || 0
            };
            md = content.msg;
        } else if (msg.type === 'music') {
            content = { title: card.title || '', source: card.source || '', coverURL: card.coverURL || '', from: card.from || '' };
            md = content.title;
        } else {
            content = msg.contentHtml || msg.content || '';
            md = msg.content || '';
        }
        return {
            oId: msg.id,
            type: msg.type,
            userName: author.userName || '',
            userNickname: author.userNickname || '',
            userAvatarURL: author.userAvatarURL || '',
            time: formatDateTime(msg.createdAt),
            md: md,
            content: content
        };
    }

    // 更新红包领取进度（内存 + DOM）
    function updateRedPacketStatus(oId, got, count) {
        if (redPacketMap[oId]) {
            redPacketMap[oId].got = got;
            redPacketMap[oId].count = count;
        }
        if (count === got) removeRpsPopup();
        const rpEl = gridEl.querySelector(`.xl-redpacket[data-oid="${oId}"]`);
        if (rpEl) {
            const statusTextEl = rpEl.querySelector('.xl-rp-status');
            const isNowEmpty = got >= count;
            if (statusTextEl) {
                statusTextEl.textContent = isNowEmpty ? '已领完' : `${got}/${count}个`;
            }
            if (isNowEmpty) {
                rpEl.classList.add('xl-rp-empty');
                rpEl.style.cursor = 'default';
            }
        }
    }

    // 创建聊天室红包（v3）
    async function sendRedPacket(payload) {
        const body = { type: payload.type, money: payload.money, message: payload.msg || '' };
        if (payload.type === 'specify') {
            const names = (payload.recivers || []).filter(Boolean);
            if (!names.length) throw new Error('请填写接收用户名');
            const ids = [];
            for (const name of names) {
                const u = await v3Fetch('/users/' + encodeURIComponent(name));
                if (u && u.id) ids.push(String(u.id));
            }
            if (!ids.length) throw new Error('未找到接收用户');
            body.recipientIds = ids;
        } else if (payload.type === 'rockPaperScissors') {
            body.count = 1;
            body.riskAccepted = true;
            body.gesture = payload.gesture != null ? payload.gesture : 0;
        } else if (payload.type === 'heartbeat') {
            body.count = payload.count || 5;
            body.riskAccepted = true;
        } else {
            body.count = payload.count;
        }
        await v3Fetch('/chat/red-packets', {
            method: 'POST',
            headers: { 'Idempotency-Key': genIdempotencyKey('rp-create') },
            body: JSON.stringify(body)
        });
    }

    // 发送聊天室普通消息（v3）
    async function sendChatMessage(text) {
        await v3Fetch('/chat/messages', {
            method: 'POST',
            headers: { 'Idempotency-Key': genIdempotencyKey('chat-msg') },
            body: JSON.stringify({ content: text })
        });
    }

    //获取并处理聊天室消息
    async function getHistoryMessages() {
        try {
            const data = await v3Fetch('/chat/messages?size=50');
            const list = (data && data.list) || [];
            list.forEach(item => {
                processChatItem(mapChatMessage(item));
            });
            statusEl.textContent = '已获取历史消息';
        } catch (err) {
            statusEl.textContent = '获取历史消息: ' + err.message;
        }
    }

    // 建立可自动重连的实时通道
    function createRealtimeChannel(getTicket, onMessage, onReady) {
        let socket = null;
        let stopped = false;
        let reconnectTimer = null;

        async function connect() {
            if (stopped) return;
            try {
                const data = await getTicket();
                if (stopped) return;
                socket = connectV3Realtime(data, onMessage, onReady);
                socket.addEventListener('close', () => {
                    socket = null;
                    scheduleReconnect();
                });
            } catch (err) {
                scheduleReconnect();
            }
        }

        function scheduleReconnect() {
            if (stopped || reconnectTimer) return;
            reconnectTimer = setTimeout(() => {
                reconnectTimer = null;
                connect();
            }, 3000);
        }

        return {
            start: connect,
            stop: function () {
                stopped = true;
                if (reconnectTimer) { clearTimeout(reconnectTimer); reconnectTimer = null; }
                if (socket) { try { socket.close(); } catch (e) { } socket = null; }
            }
        };
    }

    // 聊天室实时通道
    let chatChannel = null;

    // 关闭聊天室实时连接
    function stopChatroom() {
        if (chatChannel) { chatChannel.stop(); chatChannel = null; }
    }

    //开启聊天室消息监听
    function startLisentChatroom() {
        if (chatChannel) return;
        chatChannel = createRealtimeChannel(
            async () => v3Fetch('/chat/realtime-ticket', { method: 'POST', body: '{}' }),
            (msg) => {
                if (msg.type === 'chat.message.created' || msg.type === 'chat.message.updated') {
                    if (msg.data && msg.data.message) {
                        processChatItem(mapChatMessage(msg.data.message));
                    }
                } else if (msg.type === 'chat.red_packet.claimed') {
                    const d = msg.data || {};
                    if (d.packetId) updateRedPacketStatus(d.packetId, d.got, d.count);
                } else if (msg.type === 'chat.sync_required') {
                    messages = [];
                    renderAll();
                    getHistoryMessages();
                }
            },
            () => { statusEl.textContent = '聊天室已连接'; }
        );
        chatChannel.start();
    }

    // 通知实时通道
    let noticeChannel = null;

    //开启通知监听
    function startLisentNotice() {
        if (noticeChannel) return;
        noticeChannel = createRealtimeChannel(
            async () => v3Fetch('/realtime/tickets', { method: 'POST', body: '{}' }),
            (msg) => {
                if (msg.type === 'notifications.changed') {
                    loadNoticeUnreadCount();
                }
            }
        );
        noticeChannel.start();
    }

    // 私信实时通道
    let premsgChannel = null;

    //开启私信消息监听
    function startLisentPreMgs() {
        if (premsgChannel) return;
        premsgChannel = createRealtimeChannel(
            async () => v3Fetch('/me/messages/realtime-ticket', { method: 'POST', body: '{}' }),
            (msg) => {
                if (msg.type === 'messages.changed') {
                    loadUnreadPreMgsList();
                    loadAllPreMgsList();
                }
            }
        );
        premsgChannel.start();
    }

    //加载全部私信列表（v3 会话列表）
    async function loadAllPreMgsList() {
        const data = await v3Fetch('/me/conversations?p=1&size=50');
        allPreMgsList = (data && data.list) || [];
    }

    //加载未读私信列表（v3 会话中 unreadCount>0 的项）
    async function loadUnreadPreMgsList() {
        const data = await v3Fetch('/me/conversations?p=1&size=50');
        allPreMgsList = (data && data.list) || [];
        unreadPreMgsList = allPreMgsList.filter(item => item.unreadCount > 0);
        buildChatUnreadList();
        if (typeof updatePremsgBadge === 'function') updatePremsgBadge();
    }

    // 构建未读私信展示列表（v3 会话结构）
    function buildChatUnreadList() {
        chatUnreadList = [];
        if (!allPreMgsList || allPreMgsList.length === 0) return;
        allPreMgsList.forEach(item => {
            const unreadCount = item.unreadCount || 0;
            if (unreadCount <= 0) return;
            const peer = item.peer || {};
            const last = item.lastMessage || {};
            chatUnreadList.push({
                peerId: item.peerId,
                receiverUserName: peer.userName || '',
                receiverName: peer.userNickname || peer.userName || '未知用户',
                receiverAvatar: peer.userAvatarURL || '',
                preview: last.preview || '',
                time: last.sentAt || '',
                unreadCount: unreadCount
            });
        });
    }
    //加载全部未读通知个数
    async function loadNoticeUnreadCount() {
        try {
            let data = await v3Fetch('/me/notifications/unread-count');
            if (data) {
                const c = data.categories || {};
                noticeUnReadResult = {
                    unreadReplyNotificationCnt: c.reply || 0,
                    unreadPointNotificationCnt: c.point || 0,
                    unreadAtNotificationCnt: c.at || 0,
                    unreadBroadcastNotificationCnt: c.broadcast || 0,
                    unreadSysAnnounceNotificationCnt: c['sys-announce'] || 0,
                    unreadNewFollowerNotificationCnt: c.following || 0,
                    unreadFollowingNotificationCnt: c.following || 0,
                    unreadCommentedNotificationCnt: c.commented || 0,
                };
                noticeUnreadCnt = data.total || Object.values(noticeUnReadResult).reduce((s, v) => s + v, 0);
                if (typeof updateNoticeBadge === 'function') updateNoticeBadge();
            }
        } catch (e) {
            console.error("获取未读通知数失败:", e);
        }
    }
    /**
   * 加载各个类型未读通知列表
   * @param {string} type - 通知类型 noticeType
   *
   */
    async function loadUnreadNoticeTypeList(type) {
        try {
            const data = await v3Fetch('/me/notifications?type=' + encodeURIComponent(type) + '&status=unread&p=1&size=50');
            unreadNoticeTypeList = (data && data.list) || [];
        } catch (e) {
            unreadNoticeTypeList = [];
            console.error("获取通知列表失败:", e);
        }
    }
    // 显示红包详情弹窗
    // 显示红包详情弹窗（res 为 v3 红包详情）
    function showRedPacketDetail(res) {
        const sender = res.sender || {};
        const claims = res.claims || [];
        const bestMoney = claims.length > 0 ? Math.max(...claims.map(c => c.amount || 0)) : 0;

        // 构建领取列表
        let listHtml = '';
        claims.slice().sort((a, b) => (b.amount || 0) - (a.amount || 0)).forEach(c => {
            const u = c.user || {};
            const isBest = (c.amount || 0) === bestMoney && claims.length > 1;
            listHtml += `
        <div class="xl-rp-detail-item${isBest ? ' xl-rp-detail-item-best' : ''}">
          <img class="xl-rp-detail-item-avatar" src="${esc(u.userAvatarURL || '')}" onerror="this.src='data:image/svg+xml,...'" />
          <div class="xl-rp-detail-item-info">
            <div class="xl-rp-detail-item-name">${esc(u.userNickname || u.userName || '未知')}</div>
            <div class="xl-rp-detail-item-time">${esc(formatDateTime(c.claimedAt))}</div>
          </div>
          <div class="xl-rp-detail-item-money">¥${c.amount || 0}</div>
        </div>`;
    });

      if (claims.length === 0) {
          listHtml = '<div style="text-align:center;color:#aaa;padding:20px;font-size:12px;">暂无人领取</div>';
      }

      // 猜拳红包：展示发红包者出的手势
      let gestureHtml = '';
      if (res.senderGesture != null) {
          const gestureMap = { 0: { emoji: '✊', cn: '石头' }, 1: { emoji: '✌️', cn: '剪刀' }, 2: { emoji: '✋', cn: '布' } };
          const g = gestureMap[res.senderGesture] || { emoji: '❓', cn: '未知' };
          gestureHtml = `<div style="margin-top:6px;font-size:12px;opacity:.9;">出拳：${g.emoji} ${g.cn}</div>`;
      }

      const overlay = h(`<div class="xl-rp-overlay">
      <div class="xl-rp-detail">
        <div class="xl-rp-detail-header">
          <button class="xl-rp-detail-close">✕</button>
          <img class="xl-rp-detail-avatar" src="${esc(sender.userAvatarURL || '')}" onerror="this.style.display='none'" />
          <div class="xl-rp-detail-sender">${esc(sender.userNickname || sender.userName || '')}的红包</div>
          <div class="xl-rp-detail-msg">${esc(res.message || '恭喜发财，大吉大利')}</div>
          ${gestureHtml}
          <div class="xl-rp-detail-count">${res.got || 0}/${res.count || 0}个已领取</div>
        </div>
        <div class="xl-rp-detail-body">${listHtml}</div>
        <div class="xl-rp-detail-footer">红包 · ${new Date().toLocaleDateString()}</div>
      </div>
    </div>`);

      // 关闭事件
      overlay.querySelector('.xl-rp-detail-close').addEventListener('click', () => overlay.remove());
      overlay.addEventListener('click', (e) => { if (e.target === overlay) overlay.remove(); });

      document.body.appendChild(overlay);
  }
    // 打开红包（v3 领取后读取详情展示；领取失败仍展示公开详情）
    async function redPacketOpen(item) {
        if (isPacketOpen) return;
        isPacketOpen = true;
        try {
            const rp = redPacketMap[item.oId] || {};
            const body = {};
            if (item.gesture != null) {
                body.gesture = item.gesture;
                body.riskAccepted = true;
            } else if (rp.type === 'heartbeat') {
                body.riskAccepted = true;
            } else if (rp.type === 'rockPaperScissors') {
                body.riskAccepted = true;
                body.gesture = 0;
            }
            try {
                await v3Fetch('/chat/red-packets/' + item.oId + '/claims', {
                    method: 'POST',
                    headers: { 'Idempotency-Key': genIdempotencyKey('rp-claim') },
                    body: JSON.stringify(body)
                });
            } catch (e) {
                console.warn('领取失败，仍展示公开详情:', e.message);
            }
            const detail = await v3Fetch('/chat/red-packets/' + item.oId);
            if (detail) {
                showRedPacketDetail(detail);
                updateRedPacketStatus(item.oId, detail.got, detail.count);
            }
        } catch (err) {
            statusEl.textContent = '领取失败: ' + (err.message || err);
        } finally {
            isPacketOpen = false;
        }
    }
    // 加载用户信息
    async function loadAccountInfo() {
        accountInfo = await v3Fetch('/me');
    }
    // 加载默认表情包（v3 表情选项目录；别名映射为 Unicode 表情用于展示）
    async function loaddefaultEmoji() {
        try {
            const data = await v3Fetch('/me/settings/emotion-options');
            const groups = (data && data.groups) || [];
            const map = {};
            console.log(groups)
            groups.forEach(group => {
                (group || []).forEach(name => {
                    map[name] = defaultEmojiChars[name]?defaultEmojiChars[name]:'';
                });
            });
            defaultEmojis = map;
        } catch (e) {
            defaultEmojis = {};
            console.error('加载默认表情失败:', e);
        }
    }
    // 加载自定义表情包（历史云表情已并入“全部”分组，保持空数组兜底）
    async function loadLegacyEmotions() {
        legacyEmojis = [];
    }

    // 加载表情包分组
    async function loadEmojiGroups() {
        try {
            const data = await v3Fetch('/me/settings/emoji-groups?p=1&size=50');
            const list = (data && data.list) || [];
            emojiGroups = list.map(g => ({ oId: g.id, name: g.name, type: g.type }));
            if (emojiGroups.length > 0) {
                currentGroupIndex = 0;
                await loadGroupEmojis(emojiGroups[0].oId);
            }
        } catch (e) {
            console.error("加载表情分组失败:", e);
            emojiGroups = [];
            currentGroupIndex = 0;
        }
    }

    // 加载分组表情包
    async function loadGroupEmojis(oid) {
        try {
            const data = await v3Fetch('/me/settings/emoji-groups/' + oid + '/emojis?p=1&size=50');
            groupEmojiList = ((data && data.list) || []).map(e => ({ name: e.name, url: e.url }));
        } catch (e) {
            console.error("加载分组表情失败:", e);
            groupEmojiList = [];
        }
    }

    // 加载快捷语配置
    async function loadShortcutsConfig() {
        try {
            const raw = await cloudStorage.getItem('xl_settings');
            if (raw) {
                const cfg = JSON.parse(raw);
                shortcutsConfig = cfg.shortcutsConfig || defaultShortcutsConfig;
                if (cfg.randomRpsConfig) randomRpsConfig = { ...randomRpsConfig, ...cfg.randomRpsConfig };
            } else {
                shortcutsConfig = defaultShortcutsConfig;
            }
        } catch (e) {
            shortcutsConfig = defaultShortcutsConfig;
            console.log("快捷语配置解析失败:", e);
        }
    }

    // 单类型通知已读
    async function makeReadNotice(type) {
        try {
            await v3Fetch('/me/notifications/read', {
                method: 'POST',
                headers: { 'Idempotency-Key': genIdempotencyKey('notice-read') },
                body: JSON.stringify({ type: type })
            });
        } catch (error) {
            console.error('标记已读失败:', error);
        }
    }
    // 已读所有通知
    async function readAllNotice() {
        try {
            await v3Fetch('/me/notifications/read', {
                method: 'POST',
                headers: { 'Idempotency-Key': genIdempotencyKey('notice-read-all') },
                body: '{}'
            });
        } catch (error) {
            console.error('全部已读失败:', error);
        }
    }

    // 构建红包HTML
    function buildRedPacketHtml(rp, oId) {
        const typeCn = redPacketTypeCn[rp.type] || '普通';
        const emoji = redPacketEmoji[rp.type] || '🧧';
        const msg = rp.msg || '恭喜发财，大吉大利';
        const isEmpty = rp.got >= rp.count;
        const statusText = isEmpty ? '已领完' : `${rp.got || 0}/${rp.count}个`;
        const cls = isEmpty ? 'xl-redpacket xl-rp-empty' : 'xl-redpacket';
        const curStyle = isEmpty ? 'cursor:default' : 'cursor:pointer';
        return `<div class="${cls}" data-oid="${oId}" data-type="${rp.type}" style="${curStyle}">
      <div class="xl-rp-icon">${emoji}</div>
      <div class="xl-rp-body">
        <div class="xl-rp-type">${typeCn}红包</div>
        <div class="xl-rp-msg">${esc(msg)}</div>
        <div class="xl-rp-status">${statusText}</div>
      </div>
      <div class="xl-rp-money">¥${rp.money || ''}</div>
    </div>`;
  }

    //解析聊天室消息
    function parseMessage(item) {
        let isRpsPacket = false;
        if (item.type == "redPacket") {
            const rp = item.content;
            const oId = item.oId;
            isRpsPacket = rp.type === 'rockPaperScissors';
            // 存储红包数据（包含userName用于判断是否自己的红包）
            if (oId) redPacketMap[oId] = { ...rp, oId, userName: item.userName || rp.userName || '' };
            // 根据设置生成红包HTML或文本
            if (xlSettings.showRedPacket === false) {
                const typeCn = redPacketTypeCn[rp.type] || '普通';
                item.content = '<span style="color:#e74c3c;font-weight:600">【' + typeCn + '红包】</span>';
            } else {
                item.content = buildRedPacketHtml(rp, oId);
            }
        }
        if (item.type == "music") {
            item.content = '<span>🎵【<span style="color:#55c0e7;font-weight:600"><a href="' + item.content.source + '"target="_blank" >' + item.content.title + '</a></span>】 —— 音乐</span>';
        }
        const sender = item.userNickname !== "" ? `${item.userNickname}(${item.userName})` : item.userName;
        const time = item.time;
        // 原样保留：取纯文本内容
        const content = item.md;
        // 原样保留：取完整 HTML
        const contentHtml = item.content || '';

        return { sender, time, content, contentHtml, isRpsPacket, oId: item.oId, userName: item.userName, userAvatarURL: item.userAvatarURL, type: item.type };
    }


    /* ══════════ 样式 ══════════ */
    GM_addStyle(`
    /* ── 浮动按钮 ── */
    #_xl_fab{
      position:fixed;right:20px;bottom:20px;z-index:2147483647;
      border:none;cursor:pointer;
      background:linear-gradient(135deg,#217346,#185C37);
      box-shadow:0 4px 18px rgba(33,115,70,.5);
      display:flex;align-items:center;justify-content:center;
      transition:transform .2s,box-shadow .2s;
      color:#fff;
    }
    #_xl_fab:hover{transform:scale(1.08);box-shadow:0 6px 24px rgba(33,115,70,.6)}
    #_xl_fab svg{width:26px;height:26px;fill:#fff;pointer-events:none}

    #_xl_fab._xl_hide{display:none!important}
    #_xl_fab._xl_blink{
      animation:_xl_blinkAnim .8s ease infinite alternate;
    }
    @keyframes _xl_blinkAnim{
      from{background:linear-gradient(135deg,#217346,#185C37);box-shadow:0 4px 18px rgba(33,115,70,.5)}
      to{background:linear-gradient(135deg,#e8a735,#c78c20);box-shadow:0 4px 18px rgba(232,167,53,.6)}
    }

    /* ── 主窗口 ── */
    #_xl_win{
      position:fixed;z-index:2147483647;
      right:20px;bottom:88px;
      width:630px;height:580px;
      background:#fff;
      border:1px solid #8e8f8f;
      box-shadow:0 2px 8px rgba(0,0,0,.15),0 8px 40px rgba(0,0,0,.12);
      display:flex;flex-direction:column;
      overflow:hidden;
      font-family:'Segoe UI',system-ui,-apple-system,sans-serif;
      opacity:0;transform:translateY(14px) scale(.97);
      transition:opacity .22s,transform .22s;
      pointer-events:none;
    }
    #_xl_win._xl_open{opacity:1;transform:translateY(0) scale(1);pointer-events:auto}
    #_xl_win._xl_full{
      left:0!important;top:0!important;
      right:0!important;bottom:0!important;
      border:none!important;
      border-radius:0!important;
      width:100vw!important;
      height:100vh!important;
    }
    /* 全屏时给标签栏顶部留出空间避免被覆盖 */
    #_xl_win._xl_full .xl-titlebar{
      padding-top:4px;
    }

    /* ── 标题栏 ── */
    .xl-titlebar{
      flex-shrink:0;height:30px;
      background:#217346;display:flex;align-items:center;
      cursor:move;user-select:none;
      color:#fff;
    }
    .xl-titlebar-icon{width:60px;height:24px;margin:0 14px;flex-shrink:0}
    .xl-titlebar-icon svg{width:16px;height:16px;fill:#fff}
    .xl-titlebar-text{flex:1;font-size:11px;color:#fff;opacity:.95;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;padding-left:4px}
    .xl-titlebar-btns{display:flex;gap:0}
    .xl-tb{width:26px;height:16px;border:none;background:transparent;color:#fff;font-size:10px;cursor:pointer;display:flex;align-items:center;justify-content:center}
    .xl-tb:hover{background:rgba(255,255,255,.1)}
    .xl-tb.xl-close:hover{background:rgba(255,255,255,.1)}

    /* ── 功能区标签 ── */
    .xl-tabs{
      flex-shrink:0;height:24px;
      background:#217346;
      display:flex;align-items:flex-end;
      padding:0 12px;gap:0;
    }
    .xl-tab{
      padding:3px 12px 4px;
      font-size:11px;color:rgba(255,255,255,.75);
      cursor:pointer;border:none;background:transparent;
      transition:background .12s,color .12s;
    }
    .xl-tab:hover{background:rgba(255,255,255,.08);color:#fff}
    .xl-tab.xl-tab-file{
      background:#185C37;color:#fff;font-weight:600;
      padding:3px 16px 4px;
    }
    .xl-tab.xl-tab-file:hover{background:#1A6B3E}

    /* ── 功能区工具栏 ── */
    .xl-ribbon{
      flex-shrink:0;height:40px;
      background:#f3f3f3;
      border-bottom:1px solid #d6d6d6;
      display:flex;align-items:center;
      padding:0 8px;gap:4px;
      position:relative;
    }
    .xl-ribbon-group{
      display:flex;align-items:center;gap:2px;
      padding:0 8px;height:34px;
      border-right:1px solid #d6d6d6;
    }
    .xl-ribbon-group:last-child{border-right:none}
    .xl-rb{
      width:26px;height:26px;border:none;background:transparent;
      border-radius:2px;cursor:default;
      display:flex;align-items:center;justify-content:center;
      font-size:12px;color:#444;font-weight:600;
    }
    .xl-rb:hover{background:#dce6f0}
    .xl-ribbon-select{
      height:22px;border:1px solid #ababab;border-radius:2px;
      font-size:11px;padding:0 4px;background:#fff;color:#333;cursor:default;
    }
    .xl-ribbon-label{font-size:11px;color:#444;margin:0 4px}

    .xl-rb-input{
      width: 60px;
      background: rgba(255, 255, 255, 0.9);
      cursor: pointer;
      border: 1px solid #f3f3f3;
    }

    /* ── 表情面板 ── */
    .xl-emoji-panel{
      position:absolute;top:40px;left:0;right:0;
      background:#fff;border:1px solid #d6d6d6;border-top:none;
      box-shadow:0 4px 12px rgba(0,0,0,.12);
      z-index:10;display:flex;flex-direction:column;
      max-height:280px;
    }
    .xl-emoji-tabs{
      display:flex;border-bottom:1px solid #e0e0e0;flex-shrink:0;
    }
    .xl-emoji-tab{
      padding:6px 16px;font-size:12px;cursor:pointer;
      border:none;background:transparent;color:#666;
      border-bottom:2px solid transparent;transition:.15s;
    }
    .xl-emoji-tab:hover{color:#217346}
    .xl-emoji-tab.xl-emoji-tab-active{
      color:#217346;border-bottom-color:#217346;font-weight:600;
    }
    .xl-emoji-body{
      flex:1;overflow-y:auto;padding:8px;
      display:grid;grid-template-columns:repeat(auto-fill, 32px);
      gap:4px;justify-content:start;
    }
    .xl-emoji-item{
      width:32px;height:32px;cursor:pointer;border-radius:4px;
      display:flex;align-items:center;justify-content:center;
      transition:background .12s;
    }
    .xl-emoji-item:hover{background:#e8f5e9}
    .xl-emoji-item img{max-width:24px;max-height:24px;object-fit:contain}
    .xl-emoji-empty{
      grid-column:1/-1;text-align:center;color:#aaa;
      padding:30px 0;font-size:12px;
    }
    .xl-emoji-group-tabs{
      display:flex;border-bottom:1px solid #e0e0e0;flex-shrink:0;
      overflow-x:auto;white-space:nowrap;
    }
    .xl-emoji-group-tabs::-webkit-scrollbar{height:3px}
    .xl-emoji-group-tabs::-webkit-scrollbar-thumb{background:#ccc;border-radius:2px}
    .xl-emoji-group-tab{
      padding:4px 12px;font-size:11px;cursor:pointer;
      border:none;background:transparent;color:#888;
      border-bottom:2px solid transparent;transition:.15s;
      flex-shrink:0;
    }
    .xl-emoji-group-tab:hover{color:#217346}
    .xl-emoji-group-tab.xl-emoji-group-tab-active{
      color:#217346;border-bottom-color:#217346;font-weight:600;
    }

    /* ── 快捷语面板 ── */
    .xl-cs-panel{
      position:absolute;z-index:2147483647;
      width:280px;max-height:320px;background:#fff;
      border:1px solid #c4c4c4;box-shadow:0 4px 16px rgba(0,0,0,.18);
      display:flex;flex-direction:column;overflow:hidden;
    }
    .xl-cs-header{
      display:flex;align-items:center;justify-content:space-between;
      padding:8px 12px;border-bottom:1px solid #e0e0e0;
      font-size:12px;font-weight:600;color:#333;
    }
    .xl-cs-close{
      border:none;background:transparent;font-size:16px;
      cursor:pointer;color:#999;line-height:1;
    }
    .xl-cs-close:hover{color:#333}
    .xl-cs-body{
      flex:1;overflow-y:auto;padding:8px;
      display:flex;flex-wrap:wrap;gap:6px;
    }
    .xl-cs-btn{
      padding:6px 12px;font-size:12px;
      background:#f5f5f5;border:1px solid #ddd;
      border-radius:4px;cursor:pointer;color:#333;
      transition:all .12s;
    }
    .xl-cs-btn:hover{background:#e8f5e9;border-color:#217346;color:#217346}
    .xl-cs-empty{
      width:100%;text-align:center;color:#aaa;
      padding:24px 0;font-size:12px;
    }

    /* ── 设置面板内快捷语列表 ── */
    .xl-sc-list{max-height:160px;overflow-y:auto;margin:4px 0}
    .xl-sc-item{
      display:flex;align-items:center;gap:4px;
      padding:3px 0;font-size:11px;border-bottom:1px solid #f0f0f0;
    }
    .xl-sc-item input{
      flex:1;border:1px solid #ddd;border-radius:2px;
      padding:2px 4px;font-size:11px;min-width:0;
    }
    .xl-sc-item input:focus{border-color:#217346;outline:none}
    .xl-sc-del{
      border:none;background:transparent;color:#c00;
      cursor:pointer;font-size:14px;padding:0 2px;
    }
    .xl-sc-del:hover{color:#f00}
    .xl-sc-add,.xl-sc-save{
      border:1px solid #217346;background:#fff;color:#217346;
      border-radius:3px;font-size:11px;padding:3px 10px;
      cursor:pointer;margin-top:4px;
    }
    .xl-sc-add:hover,.xl-sc-save:hover{background:#e8f5e9}

    /* ── 消息输入栏 ── */
    .xl-formulabar{
      flex-shrink:0;height:30px;
      background:#fff;
      border-bottom:1px solid #d6d6d6;
      display:flex;align-items:center;
    }
    .xl-fb-ref{
      width:49px;height:100%;
      border:none;border-right:1px solid #d6d6d6;
      text-align:center;font-size:11px;color:#333;
      background:#f8f8f8;
      display:flex;align-items:center;justify-content:center;
      font-weight:600;
    }
    .xl-fb-fx{
      width:30px;height:100%;
      border:none;border-right:1px solid #d6d6d6;
      background:#f8f8f8;cursor:default;
      display:flex;align-items:center;justify-content:center;
      font-size:14px;font-weight:600;color:#217346;
    }
    .xl-fb-input{
      flex:1;height:100%;
      border:none;outline:none;
      padding:0 10px;font-size:12px;color:#333;
      font-family:'Segoe UI','Microsoft YaHei',sans-serif;
    }
    .xl-fb-input::placeholder{color:#aaa}
    .xl-fb-btn{
      width:70px;height:99%;
      border:none;
    }
    .xl-fb-send{
      width:60px;height:100%;
      border:none;border-left:1px solid #d6d6d6;
      background:#217346;color:#fff;
      font-size:11px;font-weight:600;
      cursor:pointer;
      display:flex;align-items:center;justify-content:center;
    }
    .xl-fb-send:hover{background:#185C37}

    /* ── 列标题 ── */
    .xl-col-header{
      flex-shrink:0;height:18px;
      background:#f3f3f3;
      border-bottom:1px solid #c4c4c4;
      display:flex;min-width:0;
    }
    .xl-rn-header{padding:0 20px;width:50px;flex-shrink:0;border-right:1px solid #c4c4c4;background:#f3f3f3;box-sizing:border-box}
    .xl-col-h{
      flex-shrink:0;height:100%;
      border-right:1px solid #c4c4c4;
      display:flex;align-items:center;justify-content:center;
      font-size:11px;color:#333;background:#f3f3f3;user-select:none;
      box-sizing:border-box;
    }
    .xl-col-a{width:115px;min-width:115px}
    .xl-col-b{width:150px;min-width:150px}
    .xl-col-c{width:300px;min-width:300px}
    .xl-col-d{flex:1;min-width:0}
    .xl-col-k{flex:1;min-width:0}

    /* ── 数据网格 ── */
    .xl-grid{
      flex:1;overflow-y:auto;overflow-x:hidden;
      background:#fff;min-width:0;min-height:0;
    }
    .xl-grid::-webkit-scrollbar{width:16px}
    .xl-grid::-webkit-scrollbar-track{background:#f0f0f0;border-left:1px solid #d4d4d4}
    .xl-grid::-webkit-scrollbar-thumb{
      background:#c1c1c1;border:4px solid #f0f0f0;border-radius:8px;min-height:40px;
    }
    .xl-grid::-webkit-scrollbar-thumb:hover{background:#a8a8a8}
    .xl-grid::-webkit-scrollbar-button{
      display:block;height:16px;background:#f0f0f0;border-left:1px solid #d4d4d4;
    }

    .xl-row{display:flex;border-bottom:1px solid #e8e8e8;min-height:20px;min-width:0}
    .xl-row:hover{background:#e2efda}
    .xl-row:nth-child(even){background:#fafafa}
    .xl-row:nth-child(even):hover{background:#e2efda}
    .xl-row.xl-row-new{
      animation:_xl_rowFlash .6s ease;
    }
    @keyframes _xl_rowFlash{
      0%{background:#fff3cd}
      100%{background:transparent}
    }

    .xl-rn{
      padding-left:10px;width:50px;min-width:50px;flex-shrink:0;
      text-align:center;font-size:10px;color:#666;
      background:#f3f3f3;border-right:1px solid #d6d6d6;
      display:flex;align-items:center;justify-content:center;user-select:none;
      box-sizing:border-box;
    }
    .xl-cell{
      flex-shrink:0;padding:2px 6px;
      font-size:11px;color:#333;
      border-right:1px solid #e8e8e8;
      overflow:hidden;text-overflow:ellipsis;white-space:nowrap;
      line-height:1.5;
      box-sizing:border-box;
    }
    .xl-cell-a{width:115px;min-width:115px;font-size:10px;color:#555}
    .xl-cell-b{width:150px;min-width:150px;font-weight:600}
    .xl-cell-c{width:300px;;min-width:300px;overflow:x};

    .xl-cell-c a:hover{text-decoration:underline !important}
    .xl-cell-c blockquote{
      margin:2px 0;padding:2px 5px;
      background:#f5f5f5;border-left:1px solid #ccc;
      color:#888;font-size:10px;
      border-radius:2px;
    }
    .xl-cell-c p {
      overflow-wrap: break-word ;
      word-wrap: break-word;
      word-break: break-word;
      white-space: normal;
    }
    .xl-cell-c a{color:#217346 !important;text-decoration:none !important}
    .xl-cell-c blockquote p{margin:2px 0;color:#888}
    .xl-cell-c p img{max-width:80px  !important;max-height:40px  !important;vertical-align:middle  !important;border-radius:2px  !important}

    /* ── 红包样式 ── */
    .xl-redpacket{
      display:inline-flex;align-items:center;
      background:linear-gradient(135deg,#e74c3c,#c0392b);
      border-radius:10px;padding:10px 14px;
      color:#fff;cursor:pointer;
      min-width:200px;max-width:280px;
      box-shadow:0 3px 12px rgba(231,76,60,.35);
      transition:transform .15s,box-shadow .15s;
      position:relative;overflow:hidden;
    }
    .xl-redpacket::before{
      content:'';position:absolute;top:-50%;left:-50%;
      width:200%;height:200%;
      background:radial-gradient(circle,rgba(255,255,255,.1) 0%,transparent 60%);
      pointer-events:none;
    }
    .xl-redpacket:hover{transform:scale(1.03);box-shadow:0 5px 18px rgba(231,76,60,.45)}
    .xl-redpacket:active{transform:scale(.97)}
    .xl-rp-icon{
      width:36px;height:36px;
      background:rgba(255,255,255,.2);border-radius:50%;
      display:flex;align-items:center;justify-content:center;
      margin-right:10px;font-size:20px;flex-shrink:0;
    }
    .xl-rp-body{flex:1;min-width:0}
    .xl-rp-type{font-size:13px;font-weight:700;margin-bottom:2px}
    .xl-rp-msg{
      font-size:10px;opacity:.85;
      overflow:hidden;text-overflow:ellipsis;white-space:nowrap;
    }
    .xl-rp-status{font-size:9px;opacity:.7;margin-top:3px}
    .xl-rp-money{
      font-size:16px;font-weight:700;margin-left:8px;
      text-shadow:0 1px 2px rgba(0,0,0,.2);flex-shrink:0;
    }
    .xl-redpacket.xl-rp-opened{
      background:linear-gradient(135deg,#e67e22,#d35400);cursor:default;
    }
    .xl-redpacket.xl-rp-empty{
      background:linear-gradient(135deg,#e67e22,#d35400);cursor:default;
    }
    .xl-redpacket.xl-rp-empty .xl-rp-icon{opacity:.5}
    .xl-redpacket.xl-rp-opening{
      animation:xl-rp-shake .4s ease;
    }
    @keyframes xl-rp-shake{
      0%,100%{transform:translateX(0)}
      20%{transform:translateX(-4px) rotate(-2deg)}
      40%{transform:translateX(4px) rotate(2deg)}
      60%{transform:translateX(-3px) rotate(-1deg)}
      80%{transform:translateX(3px) rotate(1deg)}
    }

    /* ── 红包详情弹窗 ── */
    .xl-rp-overlay{
      position:fixed;top:0;left:0;width:100vw;height:100vh;
      background:rgba(0,0,0,.55);z-index:2147483647;
      display:flex;align-items:center;justify-content:center;
      animation:xl-rp-overlay-in .2s ease;
    }
    @keyframes xl-rp-overlay-in{from{opacity:0}to{opacity:1}}
    .xl-rp-detail{
      width:340px;max-height:80vh;background:#fff;
      border-radius:14px;overflow:hidden;
      box-shadow:0 12px 48px rgba(0,0,0,.3);
      display:flex;flex-direction:column;
      animation:xl-rp-detail-in .25s ease;
    }
    @keyframes xl-rp-detail-in{from{transform:translateY(30px) scale(.95);opacity:0}to{transform:translateY(0) scale(1);opacity:1}}
    .xl-rp-detail-header{
      background:linear-gradient(135deg,#e74c3c,#c0392b);
      padding:20px 20px 16px;text-align:center;color:#fff;
      position:relative;
    }
    .xl-rp-detail-header::after{
      content:'';position:absolute;bottom:-10px;left:50%;transform:translateX(-50%);
      width:0;height:0;border-left:10px solid transparent;border-right:10px solid transparent;
      border-top:10px solid #c0392b;
    }
    .xl-rp-detail-close{
      position:absolute;top:10px;right:12px;width:28px;height:28px;
      border:none;background:rgba(255,255,255,.2);border-radius:50%;
      color:#fff;font-size:16px;cursor:pointer;
      display:flex;align-items:center;justify-content:center;
    }
    .xl-rp-detail-close:hover{background:rgba(255,255,255,.35)}
    .xl-rp-detail-avatar{
      width:52px;height:52px;border-radius:50%;
      border:2px solid rgba(255,255,255,.4);margin:0 auto 8px;
      object-fit:cover;
    }
    .xl-rp-detail-sender{font-size:14px;font-weight:600;margin-bottom:4px}
    .xl-rp-detail-msg{font-size:12px;opacity:.85;margin-bottom:8px}
    .xl-rp-detail-count{font-size:11px;opacity:.7}
    .xl-rp-detail-body{
      padding:16px 20px;overflow-y:auto;flex:1;
      max-height:calc(80vh - 160px);
    }
    .xl-rp-detail-body::-webkit-scrollbar{width:6px}
    .xl-rp-detail-body::-webkit-scrollbar-thumb{background:#ddd;border-radius:3px}
    .xl-rp-detail-item{
      display:flex;align-items:center;padding:8px 0;
      border-bottom:1px solid #f0f0f0;
    }
    .xl-rp-detail-item:last-child{border-bottom:none}
    .xl-rp-detail-item-avatar{
      width:32px;height:32px;border-radius:50%;
      margin-right:10px;flex-shrink:0;object-fit:cover;
    }
    .xl-rp-detail-item-info{flex:1;min-width:0}
    .xl-rp-detail-item-name{font-size:12px;font-weight:600;color:#333}
    .xl-rp-detail-item-time{font-size:10px;color:#999;margin-top:2px}
    .xl-rp-detail-item-money{
      font-size:14px;font-weight:700;color:#e74c3c;flex-shrink:0;
    }
    .xl-rp-detail-item-best .xl-rp-detail-item-money::after{
      content:'👑';margin-left:4px;font-size:12px;
    }
    .xl-rp-detail-footer{
      padding:12px 20px;text-align:center;
      font-size:11px;color:#999;border-top:1px solid #f0f0f0;
    }

    /* ── 猜拳手势选择弹窗 ── */
    .xl-rps-popup{
      position:absolute;z-index:10;
      background:#fff;border-radius:10px;
      box-shadow:0 6px 24px rgba(0,0,0,.2);
      padding:10px 6px;
      display:flex;gap:4px;
      animation:xl-rps-pop .2s ease;
    }
    @keyframes xl-rps-pop{from{transform:scale(.8);opacity:0}to{transform:scale(1);opacity:1}}
    .xl-rps-popup::before{
      content:'';position:absolute;bottom:-6px;left:50%;transform:translateX(-50%);
      width:0;height:0;
      border-left:6px solid transparent;border-right:6px solid transparent;
      border-top:6px solid #fff;
    }
    .xl-rps-btn{
      width:48px;height:48px;border:none;background:#f8f8f8;
      border-radius:10px;cursor:pointer;font-size:24px;
      display:flex;align-items:center;justify-content:center;
      transition:transform .12s,background .12s;
    }
    .xl-rps-btn:hover{background:#ffe5e5;transform:scale(1.1)}
    .xl-rps-btn:active{transform:scale(.95)}
    .xl-rps-btn-label{
      font-size:9px;color:#666;text-align:center;margin-top:2px;
    }

    .xl-cell-d{flex:1;min-width:0}
    /* ── 行选中 ── */
    .xl-row.xl-selected .xl-rn{background:#3573b0;color:#fff;border-color:#3573b0}
    .xl-row.xl-selected .xl-cell{background:#d6e8f8}

    /* ── 底部标签栏 + 状态栏 ── */
    .xl-bottom{flex-shrink:0;display:flex;flex-direction:column}
    .xl-sheet-tabs{
      height:24px;background:#f3f3f3;
      border-top:1px solid #c4c4c4;
      display:flex;align-items:center;
      padding:0 10px;gap:0;
    }
    .xl-stab{
      height:20px;padding:0 12px;
      font-size:10px;color:#333;
      border:1px solid #c4c4c4;border-bottom:none;
      background:#e8e8e8;cursor:pointer;
      display:flex;align-items:center;
      border-radius:0;margin-right:-1px;position:relative;top:1px;
    }
    .xl-stab.xl-stab-active{background:#fff;font-weight:600;border-top:2px solid #217346}
    .xl-stab-ctrl{
      width:18px;height:20px;border:none;background:transparent;
      cursor:pointer;display:flex;align-items:center;justify-content:center;
      color:#666;font-size:10px;margin-right:4px;
    }
    .xl-statusbar{
      height:22px;background:#217346;
      display:flex;align-items:center;
      padding:0 23px;
      font-size:11px;color:rgba(255,255,255,.88);
    }
    .xl-status-left{flex:1}
    .xl-status-right{display:flex;align-items:center;gap:12px;font-size:11px;color:rgba(255,255,255,.75)}

    /* ── 设置按钮 ── */
    .xl-tabs{position:relative}
    .xl-settings-tab,.xl-premsgs-tab,.xl-notices-tab,.xl-setting-tab{
      margin-left:auto;padding:0px 5px 2px;
      font-size:14px;color:rgba(255,255,255,.75);
      cursor:pointer;border:none;background:transparent;
      transition:background .12s,color .12s;
      display:flex;align-items:center;
      font-weight:600;
    }
    .xl-premsgs-tab{
      margin-right:10px;
      margin-left:10px;
    }
    .xl-setting-tab:hover{background:rgba(255,255,255,.08);color:#fff}

    /* ── 设置面板 ── */
    .xl-settings-popup{
      position:absolute;top:100%;right:0;z-index:10;
      width:260px;background:#fff;
      border:1px solid #c4c4c4;box-shadow:0 4px 16px rgba(0,0,0,.18);
      padding:14px 16px;display:none;
      font-family:'Segoe UI',system-ui,sans-serif;
    }
    .xl-settings-popup.xl-settings-open{display:block}
    .xl-settings-title{
      font-size:13px;font-weight:600;color:#333;
      margin-bottom:12px;padding-bottom:8px;
      border-bottom:1px solid #e0e0e0;
    }
    .xl-settings-row{
      display:flex;align-items:center;justify-content:space-between;
      margin-bottom:14px;
    }
    .xl-settings-label{font-size:12px;color:#444;flex-shrink:0}
    .xl-settings-value{font-size:11px;color:#666;min-width:32px;text-align:right;margin-left:8px}
    /* 透明度滑块 */
    .xl-opacity-slider{
      flex:1;height:4px;-webkit-appearance:none;appearance:none;
      background:#d6d6d6;border-radius:2px;outline:none;
      margin:0 10px;cursor:pointer;
    }
    .xl-opacity-slider::-webkit-slider-thumb{
      -webkit-appearance:none;appearance:none;
      width:14px;height:14px;border-radius:50%;
      background:#217346;border:2px solid #fff;
      box-shadow:0 1px 4px rgba(0,0,0,.25);cursor:pointer;
    }
    /* 开关 */
    .xl-toggle{
      position:relative;width:36px;height:18px;flex-shrink:0;
      background:#ccc;border-radius:9px;cursor:pointer;
      transition:background .25s;border:none;padding:0;
    }
    .xl-toggle::after{
      content:'';position:absolute;left:2px;top:2px;
      width:14px;height:14px;border-radius:50%;
      background:#fff;box-shadow:0 1px 3px rgba(0,0,0,.2);
      transition:transform .25s;
    }
    .xl-toggle.xl-toggle-on{background:#217346}
    .xl-toggle.xl-toggle-on::after{transform:translateX(18px)}

    /* ── 图片隐藏样式 ── */
    .xl-cell-c img.xl-img-hidden{display:none!important}
    .xl-cell-c .xl-img-placeholder{
      display:inline-block;background:#f0f0f0;color:#888;
      font-size:10px;padding:1px 5px;border-radius:2px;
      border:1px solid #ddd;
    }

    /* ── 图片预览 ── */
    .xl-img-overlay{position:fixed;top:0;left:0;width:100%;height:100%;
      background:rgba(0,0,0,.85);z-index:99999999999;display:flex;
      align-items:center;justify-content:center;cursor:zoom-out;
      animation:xl-fadeIn .2s ease}
    .xl-img-overlay img{max-width:90vw;max-height:90vh;object-fit:contain;
      border-radius:4px;box-shadow:0 4px 30px rgba(0,0,0,.5)}
    .xl-img-overlay .xl-img-close{position:absolute;top:16px;right:20px;
      color:#fff;font-size:28px;cursor:pointer;opacity:.7;
      background:none;border:none;line-height:1}
    .xl-img-overlay .xl-img-close:hover{opacity:1}
    @keyframes xl-fadeIn{from{opacity:0}to{opacity:1}}

    /* ── 通知/私信角标 ── */
    .xl-badge{
      position:absolute;top:-2px;right:-6px;
      min-width:14px;height:14px;padding:0 3px;
      background:#00ff748f;color:#fff;font-size:9px;font-weight:700;
      border-radius:7px;display:flex;align-items:center;justify-content:center;
      line-height:1;pointer-events:none;
    }

    /* ── 红包确认面板 ── */
    .xl-rp-confirm{
      position:absolute;z-index:2147483647;
      width:280px;background:#fff;
      border:1px solid #c4c4c4;box-shadow:0 4px 16px rgba(0,0,0,.18);
      border-radius:6px;overflow:hidden;
      display:flex;flex-direction:column;
      animation:xl-rps-pop .2s ease;
    }
    .xl-rp-confirm-header{
      padding:8px 12px;border-bottom:1px solid #e0e0e0;
      font-size:12px;font-weight:600;color:#333;
      display:flex;align-items:center;justify-content:space-between;
    }
    .xl-rp-confirm-body{padding:10px 12px}
    .xl-rp-confirm-row{
      display:flex;align-items:center;gap:6px;
      margin-bottom:8px;font-size:11px;color:#444;
    }
    .xl-rp-confirm-row label{flex-shrink:0;min-width:48px}
    .xl-rp-confirm-row input,.xl-rp-confirm-row select{
      flex:1;border:1px solid #ddd;border-radius:3px;
      padding:4px 6px;font-size:11px;outline:none;
    }
    .xl-rp-confirm-row input:focus,.xl-rp-confirm-row select:focus{border-color:#217346}
    .xl-rp-confirm-gestures{display:flex;gap:6px;flex:1}
    .xl-rp-confirm-gestures button{
      flex:1;padding:6px;border:1px solid #ddd;border-radius:4px;
      background:#f5f5f5;cursor:pointer;font-size:11px;
      transition:all .12s;
    }
    .xl-rp-confirm-gestures button:hover{background:#e8f5e9;border-color:#217346}
    .xl-rp-confirm-gestures button.xl-gesture-sel{background:#217346;color:#fff;border-color:#217346}
    .xl-rp-confirm-footer{
      padding:8px 12px;border-top:1px solid #e0e0e0;
      display:flex;justify-content:flex-end;gap:8px;
    }
    .xl-rp-confirm-footer button{
      padding:5px 16px;border-radius:3px;font-size:11px;
      cursor:pointer;border:1px solid #ddd;
    }
    .xl-rp-confirm-footer .xl-rp-confirm-ok{
      background:#217346;color:#fff;border-color:#217346;
    }
    .xl-rp-confirm-footer .xl-rp-confirm-ok:hover{background:#185C37}
    .xl-rp-confirm-footer .xl-rp-confirm-cancel{background:#fff;color:#333}
    .xl-rp-confirm-footer .xl-rp-confirm-cancel:hover{background:#f5f5f5}
    .xl-rp-confirm-warn{font-size:10px;color:#e67e22;margin-top:2px}

    /* ── 通知面板 ── */
    .xl-notice-panel{
      position:absolute;z-index:2147483647;
      width:320px;max-height:420px;background:#fff;
      border:1px solid #c4c4c4;box-shadow:0 4px 16px rgba(0,0,0,.18);
      border-radius:6px;overflow:hidden;
      display:flex;flex-direction:column;
      animation:xl-rps-pop .2s ease;
    }
    .xl-notice-header{
      padding:10px 12px;border-bottom:1px solid #e0e0e0;
      font-size:13px;font-weight:600;color:#333;
      display:flex;align-items:center;justify-content:space-between;
    }
    .xl-notice-header-btns{display:flex;gap:6px;align-items:center}
    .xl-notice-readall{
      font-size:10px;color:#217346;background:transparent;
      border:1px solid #217346;border-radius:3px;padding:2px 8px;
      cursor:pointer;
    }
    .xl-notice-readall:hover{background:#e8f5e9}
    .xl-notice-close{
      border:none;background:transparent;font-size:16px;
      cursor:pointer;color:#999;line-height:1;
    }
    .xl-notice-close:hover{color:#333}
    .xl-notice-body{flex:1;overflow-y:auto;padding:0}
    .xl-notice-type-item{
      display:flex;align-items:center;padding:10px 12px;
      border-bottom:1px solid #f0f0f0;cursor:pointer;
      transition:background .12s;
    }
    .xl-notice-type-item:hover{background:#e8f5e9}
    .xl-notice-type-icon{font-size:18px;margin-right:10px;width:24px;text-align:center}
    .xl-notice-type-label{flex:1;font-size:12px;color:#333}
    .xl-notice-type-cnt{
      background:#185C37;color:#fff;font-size:10px;font-weight:700;
      min-width:18px;height:18px;border-radius:9px;
      display:flex;align-items:center;justify-content:center;padding:0 4px;
    }
    .xl-notice-empty{
      text-align:center;color:#aaa;padding:40px 12px;font-size:12px;
    }
    .xl-notice-detail-item{
      padding:10px 12px;border-bottom:1px solid #f0f0f0;
      font-size:12px;color:#333;line-height:1.6;
    }
    .xl-notice-detail-item .xl-notice-detail-title{font-weight:600;margin-bottom:4px}
    .xl-notice-detail-item .xl-notice-detail-time{font-size:10px;color:#999;margin-top:4px}
    .xl-notice-detail-back{
      padding:6px 12px;font-size:11px;color:#217346;
      background:transparent;border:none;cursor:pointer;
      border-bottom:1px solid #f0f0f0;text-align:left;
    }
    .xl-notice-detail-back:hover{background:#f5f5f5}

    /* ── 私信面板 ── */
    .xl-premsg-panel{
      position:absolute;z-index:2147483647;
      width:300px;max-height:380px;background:#fff;
      border:1px solid #c4c4c4;box-shadow:0 4px 16px rgba(0,0,0,.18);
      border-radius:6px;overflow:hidden;
      display:flex;flex-direction:column;
      animation:xl-rps-pop .2s ease;
    }
    .xl-premsg-header{
      padding:10px 12px;border-bottom:1px solid #e0e0e0;
      font-size:13px;font-weight:600;color:#333;
      display:flex;align-items:center;justify-content:space-between;
    }
    .xl-premsg-close{
      border:none;background:transparent;font-size:16px;
      cursor:pointer;color:#999;line-height:1;
    }
    .xl-premsg-close:hover{color:#333}
    .xl-premsg-body{flex:1;overflow-y:auto;padding:0}
    .xl-premsg-item{
      display:flex;align-items:flex-start;padding:10px 12px;
      border-bottom:1px solid #f0f0f0;cursor:pointer;
      transition:background .12s;position:relative;
    }
    .xl-premsg-item:hover{background:#e8f5e9}
    .xl-premsg-item-avatar{
      width:36px;height:36px;border-radius:50%;
      margin-right:10px;flex-shrink:0;object-fit:cover;
    }
    .xl-premsg-item-info{flex:1;min-width:0}
    .xl-premsg-item-name{font-size:12px;font-weight:600;color:#333}
    .xl-premsg-item-preview{
      font-size:11px;color:#888;
      word-wrap:break-word;white-space:normal;
      line-height:1.4;max-height:2.8em;overflow:hidden;
    }
    .xl-premsg-item-time{font-size:10px;color:#aaa;margin-top:4px}
    .xl-premsg-item-right{display:flex;flex-direction:column;align-items:flex-end;flex-shrink:0;margin-left:8px;gap:4px}
    .xl-premsg-item-badge{
      display:inline-flex;align-items:center;justify-content:center;
      min-width:18px;height:18px;padding:0 5px;
      background:#f44336;color:#fff;border-radius:9px;
      font-size:10px;font-weight:600;
    }
    .xl-premsg-item-close{
      display:none;border:none;background:transparent;
      font-size:14px;color:#999;cursor:pointer;line-height:1;
      padding:2px;border-radius:50%;transition:all .15s;
    }
    .xl-premsg-item:hover .xl-premsg-item-close{display:inline-flex}
    .xl-premsg-item-close:hover{color:#f44336;background:#fce4ec}
    .xl-premsg-empty{
      text-align:center;color:#aaa;padding:40px 12px;font-size:12px;
    }

      /* ── 长按操作弹窗 ── */
     .xl-action-popup{
      position:absolute;z-index:50;
      background:#fff;border-radius:10px;
      box-shadow:0 6px 24px rgba(0,0,0,.22);
      padding:6px 8px;
      display:flex;gap:4px;
      animation:xl-action-pop .18s ease;
    }
    @keyframes xl-action-pop{
      from{transform:scale(.85);opacity:0}
      to{transform:scale(1);opacity:1}
    }
    /* 箭头指示关联行 */
    .xl-action-popup::after{
      content:'';position:absolute;
      width:0;height:0;
      border-left:7px solid transparent;
      border-right:7px solid transparent;
    }
    .xl-action-popup.xl-popup-above::after{
      bottom:-7px;left:50%;transform:translateX(-50%);
      border-top:7px solid #fff;
    }
    .xl-action-popup.xl-popup-below::after{
      top:-7px;left:50%;transform:translateX(-50%);
      border-bottom:7px solid #fff;
    }
    .xl-action-popup-btn{
      display:flex;flex-direction:column;align-items:center;
      justify-content:center;gap:3px;
      width:64px;height:58px;border:none;background:#f8f8f8;
      border-radius:8px;cursor:pointer;transition:all .12s;
    }
    .xl-action-popup-btn:hover{background:#e8f5e9}
    .xl-action-popup-btn:active{background:#d0eadb;transform:scale(.95)}
    .xl-action-popup-btn .xl-ap-icon{font-size:18px;line-height:1}
    .xl-action-popup-btn .xl-ap-label{font-size:10px;color:#555;font-weight:600}
    /* 被操作行高亮 */
    .xl-row.xl-row-action-target{
      background:#fff3cd !important;
      box-shadow:inset 3px 0 0 #e8a735;
    }

    /* ── 响应式 ── */
    @media(max-width:900px){
      #_xl_win{width:calc(100vw - 20px);height:calc(100vh - 100px);right:10px;bottom:80px}
      .xl-col-a{width:80px}.xl-col-b{width:120px}
      .xl-cell-a{width:80px}.xl-cell-b{width:120px}
    }

    /* ── 文章详情页（WPS Word模板） ── */
    .xl-wrd-wrap{
      position:fixed;top:0;left:0;right:0;bottom:0;
      background:#e9ebed;z-index:2147483647;
      display:flex;flex-direction:column;
      font-family:"SimSun","宋体","Microsoft YaHei",sans-serif;
      overflow:hidden;
    }
    /* 顶部菜单栏 */
    .xl-wrd-topbar{
      display: flex;
      justify-content: flex-end;
      flex-shrink: 0;
      background-color: #e8e8e8;
      position: relative;
      min-height: 60px;
    }
    .xl-wrd-topbar-left{
      flex: 1;
     }
    .xl-wrd-topbar img{
      width: 100%;height: 100%;
    }
    .xl-wrd-tab-bar{
      display:flex;gap:4px;margin-bottom:8px;
    }
    .xl-wrd-tab{
      padding:4px 14px;background:#e4e6e9;
      border-radius:4px 4px 0 0;font-size:13px;
      border:1px solid #d2d3d6;border-bottom:none;
      cursor:pointer;transition:background .12s;
    }
    .xl-wrd-tab.active{background:#fff}
    .xl-wrd-toolbar{
      position: absolute;
      right: 16px;
      bottom: 8px;
      display: flex;
      gap: 8px;
      align-items: center;
    }
    .xl-wrd-btn{
      padding:4px 9px;
      border:1px solid #d0d2d6;
      background:#fff;
      border-radius:3px;
      font-size:12px;
      cursor:pointer;
      transition:background .12s;
    }
    .xl-wrd-btn:hover{background:#e8f1ff}
    .xl-wrd-btn.active{background-color:#e0edff;border-color:#94b8e8}
    .xl-wrd-btn-close{
        padding: 4px 12px;
        border: 1px solid #dee0e5;
        background: #c6c6c636;
        border-radius: 3px;
        font-size: 12px;
        cursor: pointer;
        margin-left: auto;
        color: #434343;
        font-weight: 600;
        transition: background .12s;
    }
    .xl-wrd-btn-close:hover{background:#aaaaaa}
    /* 主体区域 */
    .xl-wrd-main{
      display:flex;flex:1;overflow:hidden;
    }
    /* 文档内容区 */
    .xl-wrd-doc{
      flex:1;overflow-y:auto;padding:24px 40px;
    }
    /* A4纸张 */
    .xl-wrd-page{
      width:794px;min-height:1123px;background:#fff;
      margin:0 auto 24px;padding:72px 90px;
      box-shadow:0 2px 12px rgba(0,0,0,.15);
      position:relative;
    }
    .xl-wrd-page p{
      font-family:"SimSun",宋体;font-size:14pt;
      line-height:1.5;text-indent:2em;
      margin:0 0 0.5em 0;color:#000;
    }
    .xl-wrd-page h1,.xl-wrd-page h2,.xl-wrd-page h3{
      text-indent:0;margin:16px 0 8px;font-weight:700;color:#222;
    }
    .xl-wrd-page h1{font-size:22pt}
    .xl-wrd-page h2{font-size:18pt}
    .xl-wrd-page h3{font-size:16pt}
    .xl-wrd-page img{max-width:100%;height:auto;margin:8px 0}
    .xl-wrd-page pre{
      background:#f6f8fa;padding:12px;border-radius:6px;
      overflow-x:auto;font-size:12pt;line-height:1.5;
      text-indent:0;
    }
    .xl-wrd-page code{
      background:#f0f0f0;padding:2px 5px;border-radius:3px;font-size:12pt;
    }
    .xl-wrd-page pre code{background:transparent;padding:0}
    .xl-wrd-page blockquote{
      border-left:4px solid #217346;padding:8px 16px;
      margin:12px 0;background:#f9fafb;color:#555;
      text-indent:0;
    }
    .xl-wrd-page a{color:#217346;text-decoration:none}
    .xl-wrd-page a:hover{text-decoration:underline}
    .xl-wrd-page table{border-collapse:collapse;width:100%;margin:12px 0}
    .xl-wrd-page th,.xl-wrd-page td{
      border:1px solid #ddd;padding:8px 12px;text-align:left;
    }
    .xl-wrd-page th{background:#f5f5f5;font-weight:600}
    /* 元信息区（作者+时间） */
    .xl-wrd-meta{
      display:flex;gap:10px;padding:10px 0;
      border-bottom:2px solid #bebebe;margin-bottom:20px;
      text-indent:0 !important;
    }
    .xl-wrd-meta span{font-size:12pt;color:#666}
    .xl-wrd-meta .xl-wrd-author{
      font-weight:700;color:#1976d2;
    }
    /* 右侧评论面板 */
    .xl-wrd-sidebar{
      width:350px;background:#f8f9fa;
      border-left:1px solid #d3d4d8;
      padding:16px 8px;overflow-y:auto;
    }
    .xl-wrd-comment-card{
      background:#fff;border:1px solid #ddd;
      border-radius:4px;padding:10px;
      margin-bottom:12px;font-size:12px;
    }
    .xl-wrd-comment-author{
      color:#1976d2;font-weight:bold;margin-bottom:4px;
    }
    .xl-wrd-comment-text{color:#333;line-height:1.5}
    .xl-wrd-comment-reply{
      margin-left:14px;margin-top:8px;
      padding-top:6px;border-top:1px solid #eee;
    }
    .xl-wrd-sidebar-empty{
      text-align:center;color:#aaa;padding:40px 12px;font-size:12px;
    }
    /* 底部状态栏 */
    .xl-wrd-statusbar{
      height:24px;background:#f3f4f6;
      border-top:1px solid #c8c9cc;
      font-size:12px;color:#555;
      line-height:24px;padding:0 12px;
      display:flex;gap:16px;flex-shrink:0;
    }
    /* 感谢气泡确认 */
    .xl-wrd-thank-bubble{
      position:absolute;z-index:10;
      background:#fff;border:1px solid #d0d2d6;
      border-radius:6px;padding:12px 16px;
      box-shadow:0 4px 16px rgba(0,0,0,.18);
      font-size:12px;color:#333;min-width:200px;
      animation:xl-bubble-in .15s ease;
    }
    @keyframes xl-bubble-in{from{opacity:0;transform:translateY(-6px)}to{opacity:1;transform:translateY(0)}}
    .xl-wrd-thank-bubble::before{
      content:'';position:absolute;top:-7px;right:16px;
      border-left:7px solid transparent;border-right:7px solid transparent;
      border-bottom:7px solid #fff;
    }
    .xl-wrd-thank-bubble .xl-tb-tip{color:#5b5754;font-weight:600;margin-bottom:8px}
    .xl-wrd-thank-bubble .xl-tb-btns{display:flex;gap:8px;justify-content:flex-end}
    .xl-wrd-thank-bubble .xl-tb-btn{
      padding:4px 14px;border-radius:3px;font-size:11px;
      cursor:pointer;border:1px solid #d0d2d6;background:#fff;
      transition:all .12s;
    }
    .xl-wrd-thank-bubble .xl-tb-btn.xl-tb-ok{background:#797979;color:#fff;border-color:#797979}
    .xl-wrd-thank-bubble .xl-tb-btn.xl-tb-ok:hover{background:#d0d2d6}
    .xl-wrd-thank-bubble .xl-tb-btn.xl-tb-cancel:hover{background:#f5f5f5}
    /* 点赞按钮状态 */
    .xl-wrd-like-active{background:#766d6d !important;color:#fff !important;border-color:#766d6d !important}
    /* 打赏区 */
    .xl-wrd-reward{
      margin:24px 0;padding:16px 20px;
      border:1px dashed #d0d2d6;border-radius:8px;
      background:#fafbfc;text-align:center;
    }
    .xl-wrd-reward-title{
      font-size:14px;font-weight:600;color:#333;margin-bottom:8px;
    }
    .xl-wrd-reward-info{
      font-size:12px;color:#888;margin-bottom:12px;
    }
    .xl-wrd-reward-info b{color:#e67e22;font-weight:600}
    .xl-wrd-reward-btn{
      display:inline-block;padding:6px 24px;
      background:#e67e22;color:#fff;border:none;border-radius:4px;
      font-size:13px;cursor:pointer;transition:background .15s;
    }
    .xl-wrd-reward-btn:hover{background:#d35400}
    .xl-wrd-reward-btn:disabled{background:#ccc;cursor:not-allowed}
    .xl-wrd-reward-content{
      text-align:left;margin-top:12px;padding:12px;
      background:#fff;border-radius:6px;border:1px solid #eee;
      font-size:13px;line-height:1.6;
    }
    .xl-wrd-reward-status{
      font-size:12px;color:#27ae60;margin-top:8px;
    }
    /* 评论回复指示 */
    .xl-wrd-reply-tag{
      display:flex;align-items:center;gap:6px;
      padding:4px 8px;background:#e8f5e9;border-radius:3px;
      font-size:11px;color:#217346;margin-bottom:6px;
    }
    .xl-wrd-reply-tag .xl-rt-close{
      cursor:pointer;color:#999;font-size:14px;line-height:1;
    }
    .xl-wrd-reply-tag .xl-rt-close:hover{color:#333}
    /* 评论输入区 */
    .xl-wrd-cmt-wrap{
      border-top:1px solid #e0e0e0;padding:10px 8px;
      background:#fff;flex-shrink:0;
    }
    .xl-wrd-cmt-toolbar{
      display:flex;gap:4px;margin-bottom:6px;align-items:center;
    }
    .xl-wrd-cmt-toolbar button{
      padding:2px 6px;border:1px solid #ddd;background:#fff;
      border-radius:3px;font-size:11px;cursor:pointer;
    }
    .xl-wrd-cmt-toolbar button:hover{background:#e8f5e9}
    .xl-wrd-cmt-textarea{
      width:95%;min-height:60px;max-height:120px;resize:vertical;
      border:1px solid #d0d2d6;border-radius:4px;padding:6px 8px;
      font-size:12px;line-height:1.5;outline:none;
      font-family:inherit;
    }
    .xl-wrd-cmt-textarea:focus{border-color:#217346;box-shadow:0 0 0 1px #217346}
    .xl-wrd-cmt-actions{
      display:flex;justify-content:space-between;align-items:center;
      margin-top:6px;
    }
    .xl-wrd-cmt-submit{
      padding:4px 16px;background:#217346;color:#fff;
      border:none;border-radius:3px;font-size:12px;
      cursor:pointer;transition:background .12s;
    }
    .xl-wrd-cmt-submit:hover{background:#1a5c30}
    .xl-wrd-cmt-submit:disabled{background:#aaa;cursor:not-allowed}
    /* 评论区emoji面板 */
    .xl-wrd-cmt-emoji-panel{
      position:absolute;bottom:100%;left:0;z-index:20;
      width:280px;max-height:240px;background:#fff;
      border:1px solid #d0d2d6;border-radius:6px;
      box-shadow:0 4px 12px rgba(0,0,0,.15);
      display:flex;flex-direction:column;overflow:hidden;
    }
    .xl-wrd-cmt-emoji-tabs{
      display:flex;border-bottom:1px solid #eee;flex-shrink:0;
    }
    .xl-wrd-cmt-emoji-tab{
      flex:1;padding:6px;text-align:center;font-size:11px;
      cursor:pointer;border:none;background:#f8f8f8;
      transition:background .12s;
    }
    .xl-wrd-cmt-emoji-tab.wce-active{background:#fff;color:#217346;font-weight:600}
    .xl-wrd-cmt-emoji-body{
      flex:1;overflow-y:auto;padding:6px;
      display:flex;flex-wrap:wrap;gap:2px;
    }
    .xl-wrd-cmt-emoji-item{
      width:32px;height:32px;display:flex;align-items:center;justify-content:center;
      cursor:pointer;border-radius:4px;transition:background .12s;
    }
    .xl-wrd-cmt-emoji-item:hover{background:#e8f5e9}
    .xl-wrd-cmt-emoji-item img{max-width:24px;max-height:24px;object-fit:contain}
    /* 评论时间 */
    .xl-wrd-comment-time{
      font-size:11px;color:#999;font-weight:400;margin-left:8px;
    }
    /* 评论中图片 */
    .xl-wrd-comment-text img{max-width:100%;border-radius:4px;margin:4px 0}
    /* 加载/错误状态 */
    .xl-wrd-loading{
      display:flex;align-items:center;justify-content:center;
      min-height:300px;font-size:14px;color:#999;
    }
    .xl-wrd-error{
      display:flex;align-items:center;justify-content:center;
      min-height:300px;font-size:14px;color:#e74c3c;
    }
  `);

    /* SVG 图标 */
    const I = {
        excel: `<svg viewBox="0 0 24 24"><rect x="2" y="2" width="20" height="20" rx="2" fill="#217346"/><text x="12" y="16" text-anchor="middle" font-size="11" font-weight="bold" fill="#fff" font-family="Segoe UI">X</text></svg>`,
        fab: `<svg viewBox="0 0 24 24"><rect x="2" y="2" width="20" height="20" rx="3" fill="none" stroke="#fff" stroke-width="1.5"/><line x1="2" y1="8" x2="22" y2="8" stroke="#fff" stroke-width="1"/><line x1="9" y1="2" x2="9" y2="22" stroke="#fff" stroke-width="1"/><line x1="15" y1="2" x2="15" y2="22" stroke="#fff" stroke-width="1"/></svg>`,
        min: `<svg viewBox="0 0 12 12"><line x1="2" y1="6" x2="10" y2="6" stroke="currentColor" stroke-width="1.2"/></svg>`,
        max: `<svg viewBox="0 0 12 12"><rect x="2" y="2" width="8" height="8" fill="none" stroke="currentColor" stroke-width="1.2"/></svg>`,
        rest: `<svg viewBox="0 0 12 12"><rect x="3.5" y="1" width="7" height="7" fill="none" stroke="currentColor" stroke-width="1"/><rect x="1" y="3.5" width="7" height="7" fill="#f3f3f3" stroke="currentColor" stroke-width="1"/></svg>`,
        close: `<svg viewBox="0 0 12 12"><line x1="2" y1="2" x2="10" y2="10" stroke="currentColor" stroke-width="1.3"/><line x1="10" y1="2" x2="2" y2="10" stroke="currentColor" stroke-width="1.3"/></svg>`
  };

    function h(html) {
        const t = document.createElement('template');
        t.innerHTML = html.trim();
        return t.content.firstChild;
    }

    /* ══════════ 构建 DOM ══════════ */

    // 浮动按钮
    const fab = h(`<button id="_xl_fab" title="打开表格">新建Microsoft工作表.xlsx</button>`);
    document.body.appendChild(fab);

    // 主窗口
    const win = h(`
    <div id="_xl_win">
      <!-- 标题栏 -->
      <div class="xl-titlebar" id="_xl_drag">
        <div class="xl-titlebar-icon">WPS表格</div>
        <div class="xl-titlebar-text">新建Microsoft工作表 - Excel</div>
        <div class="xl-titlebar-btns">
          <button class="xl-tb" id="_xl_min" title="最小化">${I.min}</button>
          <button class="xl-tb" id="_xl_max" title="最大化">${I.max}</button>
          <button class="xl-tb xl-close" id="_xl_close" title="关闭">${I.close}</button>
        </div>
      </div>

      <!-- 标签栏 -->
      <div class="xl-tabs" id="_xl_tabs">
        <span class="xl-tab" title="最新" id="_xl_tabs_article">文件</span>
        <span class="xl-tab" title="聊天室" id="_xl_tabs_chatroom">开始</span>
        <span class="xl-tab" title="专栏" id="_xl_tabs_column">插入</span>
        <span class="xl-tab">页面布局</span>
        <span class="xl-tab">公式</span>
        <span class="xl-tab">数据</span>
        <span class="xl-tab">审阅</span>
        <span class="xl-tab">视图</span>
        <div class="xl-settings-tab">
            <span class="xl-notices-tab" id="_xl_notices_btn" title="通知">🕭</span>
            <span class="xl-premsgs-tab" id="_xl_premsgs_btn" title="私信">✉</span>
            <span class="xl-setting-tab" id="_xl_settings_btn" title="设置">⚙</span>
        </div>
        <!-- 设置面板 -->
        <div class="xl-settings-popup" id="_xl_settings_popup">
          <div class="xl-settings-title">⚙ 设置</div>
          <div class="xl-settings-row">
            <span class="xl-settings-label">透明度</span>
            <input type="range" class="xl-opacity-slider" id="_xl_opacity_slider" min="30" max="100" value="100" />
            <span class="xl-settings-value" id="_xl_opacity_val">100%</span>
          </div>
          <div class="xl-settings-row">
            <span class="xl-settings-label">显示聊天图片</span>
            <button class="xl-toggle xl-toggle-on" id="_xl_img_toggle"></button>
          </div>
           <div class="xl-settings-row" style="margin-top:8px;border-top:1px solid #e0e0e0;padding-top:10px">
            <span class="xl-settings-label">快捷语配置</span>
            <button class="xl-sc-add" id="_xl_sc_add_btn">+ 添加</button>
          </div>
          <div class="xl-sc-list" id="_xl_sc_list"></div>
          <div class="xl-settings-row" style="margin-top:8px;border-top:1px solid #e0e0e0;padding-top:10px">
            <span class="xl-settings-label">红包显示</span>
            <button class="xl-toggle xl-toggle-on" id="_xl_rp_toggle"></button>
          </div>
          <div class="xl-settings-row" style="margin-top:8px;border-top:1px solid #e0e0e0;padding-top:10px">
            <span class="xl-settings-label">随机出拳（点猜拳按钮直接发出）</span>
            <button class="xl-toggle" id="_xl_rps_toggle"></button>
          </div>
          <div class="xl-settings-row">
            <span class="xl-settings-label">猜拳积分</span>
            <input type="number" class="xl-sc-input" id="_xl_rps_money" min="256" value="256" style="width:60px;border:1px solid #ddd;border-radius:2px;padding:2px 4px;font-size:11px" />
          </div>
          <div class="xl-settings-row" style="margin-top:8px;border-top:1px solid #e0e0e0;padding-top:10px">
            <span class="xl-settings-label" style="font-weight:600">快捷键设置</span>
          </div>
          <div class="xl-settings-row">
            <span class="xl-settings-label">显示/隐藏小框</span>
            <input type="text" class="xl-sc-input" id="_xl_hotkey_small" placeholder="Ctrl+Alt+M" readonly style="width:100px;border:1px solid #ddd;border-radius:2px;padding:2px 4px;font-size:11px;text-align:center;cursor:pointer" />
          </div>
          <div class="xl-settings-row" style="justify-content:bet;gap:8px;margin-top:10px;padding-top:10px;border-top:1px solid #e0e0e0;">
            <button class="xl-sc-save" id="_xl_hotkey_reset_btn" style="font-size:12px;padding:4px 16px;">恢复默认</button>
            <button class="xl-sc-save" id="_xl_settings_save_btn" style="font-size:12px;padding:4px 16px;background:#217346;color:#fff;border-radius:3px;">保存设置</button>
          </div>
        </div>
      </div>

      <!-- 功能区 -->
      <div class="xl-ribbon">
        <div class="xl-ribbon-group">
          <button class="xl-rb" title="自动滚动" id="_xl_scroll_btn" style='opacity:0.6' >🗁</button>
          <button class="xl-rb" title="暂停/恢复监听" id="_xl_pause_btn" >🖫</button>
          <button class="xl-rb"  title="清空记录" id="_xl_clear_btn">🖶</button>
        </div>
        <div class="xl-ribbon-group">
          <span class="xl-ribbon-label" id="_xl_live_label">⚫︎</span>
        </div>
        <div class="xl-ribbon-group" style="flex:1">
          <input type="text" class="xl-rb-input" id='drdafont' placeholder="宋体" disabled/>
          <input type="text" class="xl-rb-input" id='drdafontsize'  placeholder="12" disabled/>
          <button class="xl-rb" title="emoji" id="_xl_emoji_btn" style="font-weight:800">B</button>
          <button class="xl-rb" title="收藏表情" id="_xl_legacy_emoji_btn" style="font-style:italic">I</button>
          <button class="xl-rb" title="快捷发送" id="_xl_cs_btn" style="text-decoration:underline ">U</button>
          <button class="xl-rb" title="猜拳红包" id="_xl_rps_btn">亖</button>
          <button class="xl-rb" title="手气红包" id="_xl_rd_btn">田</button>
          <button class="xl-rb" title="专属红包" id="_xl_sf_btn">Σ</button>
          <button class="xl-rb" title="心跳红包" id="_xl_hd_btn">Ω</button>
          <button class="xl-rb" title="普通红包" id="_xl_vg_btn">🔍︎</button>
        </div>
      </div>

      <!-- 消息输入栏 -->
      <div class="xl-formulabar">
        <div class="xl-fb-ref" id="_xl_cell_ref">C 1</div>
        <div class="xl-fb-fx">f(x)</div>
        <input class="xl-fb-input" id="_xl_msg_input" placeholder="在此输入…" />
        <!--  <button class="xl-fb-btn" id="_xl_upflie_btn">上传图片</button> -->
        <button class="xl-fb-btn" id="_xl_upflie_btn">发 送</button>
      </div>

      <!-- 列标题 -->
      <div class="xl-col-header">
        <div class="xl-rn-header"></div>
        <div class="xl-col-h xl-col-a">A</div>
        <div class="xl-col-h xl-col-b">B</div>
        <div class="xl-col-h xl-col-c">C</div>
        <div class="xl-col-h xl-col-d">D</div>
        <div class="xl-col-h xl-col-d">E</div>
        <div class="xl-col-h xl-col-d">F</div>
        <div class="xl-col-h xl-col-d">G</div>
        <div class="xl-col-h xl-col-d">H</div>
        <div class="xl-col-h xl-col-d">I</div>
        <div class="xl-col-h xl-col-d">J</div>
        <div class="xl-col-h xl-col-d">K</div>
      </div>

      <!-- 数据网格 -->
      <div class="xl-grid" id="_xl_grid">
        <div style="text-align:center;color:#aaa;padding:60px 20px;font-size:12px;">
          等待聊天室加载…<br>消息将实时显示在此处
        </div>
      </div>

      <!-- 底部 -->
      <div class="xl-bottom">
        <div class="xl-sheet-tabs">
          <button class="xl-stab-ctrl" title="导航">◀</button>
          <span class="xl-stab xl-stab-active">sheet1</span>
        </div>
        <div class="xl-statusbar">
          <span class="xl-status-left" id="_xl_status">就绪</span>
          <span class="xl-status-right" id="_xl_stat">共 0 行</span>
        </div>
      </div>
    </div>
  `);
    document.body.appendChild(win);

    // ── 面板定位辅助：将面板限制在Excel窗口内 ──
    function positionPanel(anchorBtn, panel, panelW, panelH, opts) {
        opts = opts || {};
        var aRect = anchorBtn.getBoundingClientRect();
        var wRect = win.getBoundingClientRect();
        var top, left;
        if (opts.align === 'right') {
            left = aRect.right - panelW - wRect.left;
        } else {
            left = aRect.left - wRect.left;
        }
        if (opts.above) {
            top = aRect.top - panelH - 4 - wRect.top;
        } else {
            top = aRect.bottom + 4 - wRect.top;
        }
        left = Math.max(4, Math.min(left, wRect.width - panelW - 4));
        top = Math.max(4, Math.min(top, wRect.height - panelH - 4));
        panel.style.top = top + 'px';
        panel.style.left = left + 'px';
    }

    const gridEl = win.querySelector('#_xl_grid');
    const msgInput = win.querySelector('#_xl_msg_input');
    const cellRef = win.querySelector('#_xl_cell_ref');
    const statEl = win.querySelector('#_xl_stat');
    const statusEl = win.querySelector('#_xl_status');
    const liveLabel = win.querySelector('#_xl_live_label');
    const maxBtn = win.querySelector('#_xl_max');
    const pauseBtn = win.querySelector('#_xl_pause_btn');
    const clearBtn = win.querySelector('#_xl_clear_btn');
    const scrollBtn = win.querySelector('#_xl_scroll_btn');
    const emojiBtn = win.querySelector('#_xl_emoji_btn');
    const legacyEmojiBtn = win.querySelector('#_xl_legacy_emoji_btn');
    const articleTab = win.querySelector('#_xl_tabs_article');
    const chatroomTab = win.querySelector('#_xl_tabs_chatroom');
    const columnTab = win.querySelector('#_xl_tabs_column');

    if (chatroomTab) {
        chatroomTab.setAttribute('class', 'xl-tab xl-tab-file');
    }

    // ── 文件上传 ──
    const fileInput = h('<input type="file" id="_xl_file_input" accept="image/*" multiple style="display:none" />');
    document.body.appendChild(fileInput);


    // ── 表情面板 ──
    let emojiPanel = null;
    let emojiPanelMode = 'default'; // 'default' | 'legacy'

    function removeEmojiPanel() {
        if (emojiPanel) { emojiPanel.remove(); emojiPanel = null; }
    }

    function insertEmoji(tag) {
        // 在光标位置插入文本
        const start = msgInput.selectionStart;
        const end = msgInput.selectionEnd;
        const val = msgInput.value;
        msgInput.value = val.slice(0, start) + tag + val.slice(end);
        msgInput.selectionStart = msgInput.selectionEnd = start + tag.length;
        msgInput.focus();
    }

    function renderEmojiPanel(mode) {
        if (!isPanelOpen) return;
        removeEmojiPanel();
        emojiPanelMode = mode;
        const panel = document.createElement('div');
        panel.className = 'xl-emoji-panel';

        // 标签栏
        const tabs = document.createElement('div');
        tabs.className = 'xl-emoji-tabs';
        const tabDefault = document.createElement('button');
        tabDefault.className = 'xl-emoji-tab' + (mode === 'default' ? ' xl-emoji-tab-active' : '');
        tabDefault.textContent = '默认表情';
        tabDefault.addEventListener('click', (e) => { e.stopPropagation(); renderEmojiPanel('default'); });
        const tabLegacy = document.createElement('button');
        tabLegacy.className = 'xl-emoji-tab' + (mode === 'legacy' ? ' xl-emoji-tab-active' : '');
        tabLegacy.textContent = '收藏表情';
        tabLegacy.addEventListener('click', (e) => { e.stopPropagation(); renderEmojiPanel('legacy'); });
        tabs.appendChild(tabDefault);
        tabs.appendChild(tabLegacy);
        panel.appendChild(tabs);

        // 内容区
        const body = document.createElement('div');
        body.className = 'xl-emoji-body';

        if (mode === 'default') {
            const keys = Object.keys(defaultEmojis);
            if (keys.length === 0) {
                body.innerHTML = '<div class="xl-emoji-empty">暂无默认表情</div>';
            } else {
                body.style.display = 'flex';
                body.style.flexWrap = 'wrap';
                keys.forEach(name => {
                    const item = document.createElement('div');
                    item.className = 'xl-emoji-item';
                    item.title = name;
                    item.style.width = 'auto';
                    item.style.height = 'auto';
                    item.style.padding = '4px 6px';
                    item.style.fontSize = '16px';
                    item.style.whiteSpace = 'nowrap';
                    item.textContent = defaultEmojis[name] || (':' + name + ':');
                    item.addEventListener('click', () => {
                        insertEmoji(`:${name}:`);
                        removeEmojiPanel();
                    });
                    body.appendChild(item);
                });
            }
        } else {
            // 收藏表情模式：分组子标签 + 表情列表
            // 分组子标签栏
            if (emojiGroups && emojiGroups.length > 0) {
                const groupTabs = document.createElement('div');
                groupTabs.className = 'xl-emoji-group-tabs';
                emojiGroups.forEach((group, idx) => {
                    const gTab = document.createElement('button');
                    gTab.className = 'xl-emoji-group-tab' + (idx === currentGroupIndex ? ' xl-emoji-group-tab-active' : '');
                    gTab.textContent = group.name;
                    gTab.addEventListener('click', async (e) => {
                        e.stopPropagation();
                        currentGroupIndex = idx;
                        // 加载该分组表情包
                        if (group.oId === 'all') {
                            // 回退模式的"全部"分组，直接使用 legacyEmojis
                            groupEmojiList = [];
                        } else {
                            await loadGroupEmojis(group.oId);
                        }
                        renderEmojiPanel('legacy');
                    });
                    groupTabs.appendChild(gTab);
                });
                panel.appendChild(groupTabs);
            }

            // 获取当前分组的表情列表
            const currentEmojis = (emojiGroups.length > 0 && emojiGroups[currentGroupIndex] && emojiGroups[currentGroupIndex].oId === 'all')
            ? legacyEmojis
            : groupEmojiList;

            if (!currentEmojis || currentEmojis.length === 0) {
                body.innerHTML = '<div class="xl-emoji-empty">暂无收藏表情</div>';
            } else {
                currentEmojis.forEach(eitem => {
                    const item = document.createElement('div');
                    item.className = 'xl-emoji-item';
                    item.innerHTML = `<img src="${eitem.url}" />`;
                    item.addEventListener('click', () => {
                        insertEmoji(`![图片](${eitem.url})`);
                        removeEmojiPanel();
                    });
                    body.appendChild(item);
                });
            }
        }

        panel.appendChild(body);
        const ribbon = win.querySelector('.xl-ribbon');
        (ribbon || win).appendChild(panel);
        emojiPanel = panel;
    }

    function toggleEmojiPanel(mode) {
        if (emojiPanel && emojiPanelMode === mode) {
            removeEmojiPanel();
        } else {
            renderEmojiPanel(mode);
        }
    }

    // 点击面板外部关闭
    document.addEventListener('click', (e) => {
        if (!emojiPanel) return;
        if (!emojiPanel.contains(e.target) && e.target !== emojiBtn && e.target !== legacyEmojiBtn) {
            removeEmojiPanel();
        }
    });

    emojiBtn.addEventListener('click', (e) => { e.stopPropagation(); toggleEmojiPanel('default'); });
    legacyEmojiBtn.addEventListener('click', (e) => { e.stopPropagation(); toggleEmojiPanel('legacy'); });

    // ── 快捷语面板 ──
    const csBtn = win.querySelector('#_xl_cs_btn');
    let csPanel = null;

    function removeCsPanel() {
        if (csPanel) { csPanel.remove(); csPanel = null; }
    }

    function renderCsPanel() {
        if (!isPanelOpen) return;
        removeCsPanel();
        const panel = document.createElement('div');
        panel.className = 'xl-cs-panel';

        const header = document.createElement('div');
        header.className = 'xl-cs-header';
        header.innerHTML = '<span>快捷语</span>';
        const closeBtn = document.createElement('button');
        closeBtn.className = 'xl-cs-close';
        closeBtn.textContent = '✕';
        closeBtn.addEventListener('click', (e) => { e.stopPropagation(); removeCsPanel(); });
        header.appendChild(closeBtn);
        panel.appendChild(header);

        const body = document.createElement('div');
        body.className = 'xl-cs-body';
        if (!shortcutsConfig || shortcutsConfig.length === 0) {
            body.innerHTML = '<div class="xl-cs-empty">暂无快捷语，请在设置中配置</div>';
        } else {
            shortcutsConfig.forEach(sc => {
                const btn = document.createElement('button');
                btn.className = 'xl-cs-btn';
                btn.textContent = sc.title;
                btn.title = sc.value;
                btn.addEventListener('click', async (e) => {
                    e.stopPropagation();
                    // 直接发送
                    const text = sc.value;
                    if (text) {
                        try {
                            await sendChatMessage(text);
                            statusEl.textContent = '快捷语已发送';
                            setTimeout(() => { statusEl.textContent = isPaused ? '已暂停' : '监听中'; }, 5000);
                        } catch (err) {
                            statusEl.textContent = '发送失败: ' + err.message;
                        }
                    }
                    removeCsPanel();
                });
                body.appendChild(btn);
            });
        }
        panel.appendChild(body);

        // 阻止面板内点击冒泡
        panel.addEventListener('click', (e) => e.stopPropagation());
        // 定位到按钮下方（限制在窗口内）
        win.appendChild(panel);
        positionPanel(csBtn, panel, 280, panel.offsetHeight || 320);
        csPanel = panel;
    }

    csBtn.addEventListener('click', (e) => {
        e.stopPropagation();
        if (csPanel) { removeCsPanel(); } else { renderCsPanel(); }
    });

    // 点击外部关闭快捷语面板
    document.addEventListener('click', (e) => {
        if (!csPanel) return;
        if (!csPanel.contains(e.target) && e.target !== csBtn) {
            removeCsPanel();
        }
    });

    // ── 快捷语设置：渲染列表 ──
    const scListEl = win.querySelector('#_xl_sc_list');
    const scAddBtn = win.querySelector('#_xl_sc_add_btn');
    const scSaveBtn = win.querySelector('#_xl_settings_save_btn');
    const rpsToggle = win.querySelector('#_xl_rps_toggle');
    const rpsMoneyInput = win.querySelector('#_xl_rps_money');

    function renderScList() {
        if (!scListEl) return;
        scListEl.innerHTML = '';
        shortcutsConfig.forEach((sc, i) => {
            const item = document.createElement('div');
            item.className = 'xl-sc-item';
            item.innerHTML = `
        <input type="text" data-idx="${i}" data-field="title" value="${esc(sc.title || '')}" placeholder="名称" />
        <input type="text" data-idx="${i}" data-field="value" value="${esc(sc.value || '')}" placeholder="内容" style="flex:2" />
        <button class="xl-sc-del" data-idx="${i}">✕</button>`;
        scListEl.appendChild(item);
    });
  }

    scAddBtn.addEventListener('click', (e) => {
        e.stopPropagation();
        shortcutsConfig.push({ title: '', value: '' });
        renderScList();
    });

    scListEl.addEventListener('click', (e) => {
        const delBtn = e.target.closest('.xl-sc-del');
        if (!delBtn) return;
        const idx = parseInt(delBtn.dataset.idx, 10);
        shortcutsConfig.splice(idx, 1);
        renderScList();
    });

    scSaveBtn.addEventListener('click', (e) => {
        e.stopPropagation();
        // 从输入框同步数据
        scListEl.querySelectorAll('input').forEach(inp => {
            const idx = parseInt(inp.dataset.idx, 10);
            const field = inp.dataset.field;
            if (shortcutsConfig[idx] && field) shortcutsConfig[idx][field] = inp.value;
        });
        // 过滤掉空项
        shortcutsConfig = shortcutsConfig.filter(sc => sc.title && sc.value);
        xlSettings.shortcutsConfig = shortcutsConfig;
        xlSettings.randomRpsConfig = randomRpsConfig;
        renderScList();
        statusEl.textContent = '快捷语配置已保存，点击底部"保存设置"生效';
        setTimeout(() => { statusEl.textContent = isPaused ? '已暂停' : '监听中'; }, 5000);
    });

    // ── 随机出拳设置 ──
    function applyRpsConfig() {
        if (rpsToggle) rpsToggle.classList.toggle('xl-toggle-on', randomRpsConfig.enabled);
        if (rpsMoneyInput) rpsMoneyInput.value = randomRpsConfig.minMoney;
    }

    rpsToggle.addEventListener('click', (e) => {
        e.stopPropagation();
        randomRpsConfig.enabled = !randomRpsConfig.enabled;
        rpsToggle.classList.toggle('xl-toggle-on', randomRpsConfig.enabled);
        xlSettings.randomRpsConfig = randomRpsConfig;
    });

    rpsMoneyInput.addEventListener('input', (e) => {
        e.stopPropagation();
        let v = parseInt(rpsMoneyInput.value, 10) || 256;
        if (v < 256) v = 256;
        randomRpsConfig.minMoney = v;
    });

    rpsMoneyInput.addEventListener('blur', function () {
        let v = parseInt(rpsMoneyInput.value, 10) || 256;
        if (v < 256) v = 256;
        randomRpsConfig.minMoney = v;
        xlSettings.randomRpsConfig = randomRpsConfig;
    });

    rpsMoneyInput.addEventListener('click', (e) => e.stopPropagation());

    // ── 红包确认面板通用逻辑 ──
    let activeRpConfirm = null;

    function removeRpConfirm() {
        if (activeRpConfirm) { activeRpConfirm.remove(); activeRpConfirm = null; }
    }

    /**
   * 显示红包确认面板
   * @param {HTMLElement} anchorBtn - 触发按钮
   * @param {string} title - 面板标题
   * @param {string} type - 红包类型 (rockPaperScissors/random/average/heartbeat/specify)
   * @param {Array} fields - 字段配置 [{label,type,inputType,min,default,placeholder,name,options?}]
   * @param {string} defaultMsg - 默认祝福语
   */
    function showRpConfirm(anchorBtn, title, type, fields, defaultMsg) {
        if (!isPanelOpen) return;
        removeRpConfirm();
        const overlay = document.createElement('div');
        overlay.className = 'xl-rps-popup-container';
        overlay.style.cssText = 'position:absolute;z-index:2147483647;top:0;left:0;width:100%;height:100%;';
        overlay.innerHTML = '<div style="position:absolute;top:0;left:0;width:100%;height:100%;"></div>';

        const panel = document.createElement('div');
        panel.className = 'xl-rp-confirm';

        // Header
        panel.innerHTML = `<div class="xl-rp-confirm-header"><span>${esc(title)}</span><button class="xl-notice-close">✕</button></div>`;

        // Body
        const body = document.createElement('div');
        body.className = 'xl-rp-confirm-body';

        const fieldEls = {};
        fields.forEach(f => {
            const row = document.createElement('div');
            row.className = 'xl-rp-confirm-row';
            let inputHtml = '';
            if (f.type === 'gesture') {
                inputHtml = `<div class="xl-rp-confirm-gestures" data-name="${f.name}">
          <button data-val="0">✊ 石头</button>
          <button data-val="1">✌️ 剪刀</button>
          <button data-val="2">✋ 布</button>
        </div>`;
      } else if (f.type === 'select') {
          let opts = (f.options || []).map(o => `<option value="${o.value}">${esc(o.label)}</option>`).join('');
          inputHtml = `<select data-name="${f.name}">${opts}</select>`;
      } else {
          inputHtml = `<input type="${f.inputType || 'number'}" data-name="${f.name}" min="${f.min || 0}" value="${f.default}" placeholder="${esc(f.placeholder || '')}" />`;
      }
        row.innerHTML = `<label>${esc(f.label)}</label>${inputHtml}`;
        body.appendChild(row);

        if (f.type === 'gesture') {
            const gestureWrap = row.querySelector('.xl-rp-confirm-gestures');
            const defaultVal = f.default != null ? String(f.default) : '0';
            gestureWrap.querySelectorAll('button').forEach(btn => {
                if (btn.dataset.val === defaultVal) btn.classList.add('xl-gesture-sel');
                btn.addEventListener('click', (ev) => {
                    ev.stopPropagation();
                    gestureWrap.querySelectorAll('button').forEach(b => b.classList.remove('xl-gesture-sel'));
                    btn.classList.add('xl-gesture-sel');
                });
            });
            fieldEls[f.name] = gestureWrap;
        } else {
            fieldEls[f.name] = row.querySelector(`[data-name="${f.name}"]`);
        }
    });

      // 祝福语
      const msgRow = document.createElement('div');
      msgRow.className = 'xl-rp-confirm-row';
      msgRow.innerHTML = `<label>祝福语</label><input type="text" data-name="msg" value="${esc(defaultMsg)}" placeholder="请输入祝福语" />`;
      body.appendChild(msgRow);
      fieldEls['msg'] = msgRow.querySelector('[data-name="msg"]');

      panel.appendChild(body);

      // Footer
      const footer = document.createElement('div');
      footer.className = 'xl-rp-confirm-footer';
      footer.innerHTML = '<button class="xl-rp-confirm-cancel">取消</button><button class="xl-rp-confirm-ok">发送</button>';
      panel.appendChild(footer);

      overlay.appendChild(panel);
      win.appendChild(overlay);
      activeRpConfirm = overlay;

      // 定位（限制在Excel窗口内）
      positionPanel(anchorBtn, panel, 280, panel.offsetHeight || 380, { align: 'left' });

      // 关闭
      overlay.firstChild.addEventListener('click', removeRpConfirm);
      panel.querySelector('.xl-notice-close').addEventListener('click', (e) => { e.stopPropagation(); removeRpConfirm(); });
      panel.querySelector('.xl-rp-confirm-cancel').addEventListener('click', (e) => { e.stopPropagation(); removeRpConfirm(); });
      panel.addEventListener('click', (e) => e.stopPropagation());

      // 发送
      panel.querySelector('.xl-rp-confirm-ok').addEventListener('click', async (e) => {
          e.stopPropagation();
          const payload = { type, recivers: [] };
          fields.forEach(f => {
              if (f.type === 'gesture') {
                  const selBtn = fieldEls[f.name].querySelector('.xl-gesture-sel');
                  payload[f.name] = selBtn ? parseInt(selBtn.dataset.val, 10) : 0;
              } else if (f.type === 'select') {
                  payload[f.name] = fieldEls[f.name].value;
              } else if (f.type === 'text') {
                  payload[f.name] = fieldEls[f.name].value.trim();
              } else {
                  let v = parseInt(fieldEls[f.name].value, 10);
                  if (f.min != null && v < f.min) v = f.min;
                  payload[f.name] = v;
              }
          });
          payload.msg = fieldEls['msg'].value || defaultMsg;
          // 专属红包：将用户名字符串转为数组
          if (type === 'specify') {
              const name = (payload.recivers || '').trim();
              payload.recivers = name ? [name] : [];
          }
          if (type === 'rockPaperScissors') {
              payload.count = 1;
          }
          try {
              await sendRedPacket(payload);
              statusEl.textContent = `已发送${title}`;
              setTimeout(() => { statusEl.textContent = isPaused ? '已暂停' : '监听中'; }, 8000);
          } catch (err) {
              statusEl.textContent = '发送失败: ' + err.message;
          }
          removeRpConfirm();
      });
  }

    // ── 猜拳红包按钮 ──
    const rpsBtn = win.querySelector('#_xl_rps_btn');
    rpsBtn.addEventListener('click', async (e) => {
        e.stopPropagation();
        if (randomRpsConfig.enabled) {
            // 随机出拳模式：直接发送
            const gestures = [0, 1, 2];
            const gesture = gestures[Math.floor(Math.random() * 3)];
            const money = Math.max(256, randomRpsConfig.minMoney);
            try {
                await sendRedPacket({
                    type: 'rockPaperScissors', money, count: 1,
                    msg: '猜拳红包！', recivers: [], gesture
                });
                statusEl.textContent = `已发送猜拳红包（${money}积分）`;
                setTimeout(() => { statusEl.textContent = isPaused ? '已暂停' : '监听中'; }, 8000);
            } catch (err) { statusEl.textContent = '发送失败: ' + err.message; }
        } else {
            // 非随机模式：弹出确认面板
            showRpConfirm(rpsBtn, '猜拳红包', 'rockPaperScissors', [
                { label: '手势', type: 'gesture', name: 'gesture', default: 0,count: 1 },
                { label: '积分', type: 'number', inputType: 'number', min: 256, default: 256, placeholder: '≥256', name: 'money' }
            ], '石头剪刀布！');
        }
    });

    // ── 手气红包按钮 ──
    const rdBtn = win.querySelector('#_xl_rd_btn');
    rdBtn.addEventListener('click', (e) => {
        e.stopPropagation();
        showRpConfirm(rdBtn, '手气红包', 'random', [
            { label: '积分', type: 'number', inputType: 'number', min: 32, default: 32, placeholder: '≥32', name: 'money' },
            { label: '个数', type: 'number', inputType: 'number', min: 1, default: 1, placeholder: '≥1', name: 'count' }
        ], '摸鱼者，事竟成！');
    });

    // ── 心跳红包按钮 ──
    const hdBtn = win.querySelector('#_xl_hd_btn');
    hdBtn.addEventListener('click', (e) => {
        e.stopPropagation();
        showRpConfirm(hdBtn, '心跳红包', 'heartbeat', [
            { label: '积分', type: 'number', inputType: 'number', min: 32, default: 32, placeholder: '≥32', name: 'money' },
            { label: '个数', type: 'number', inputType: 'number', min: 5, default: 5, placeholder: '≥5', name: 'count' }
        ], '玩的就是心跳！');
    });

    // ── 普通红包按钮 ──
    const vgBtn = win.querySelector('#_xl_vg_btn');
    vgBtn.addEventListener('click', (e) => {
        e.stopPropagation();
        showRpConfirm(vgBtn, '普通红包', 'average', [
            { label: '积分', type: 'number', inputType: 'number', min: 32, default: 32, placeholder: '≥32', name: 'money' },
            { label: '个数', type: 'number', inputType: 'number', min: 1, default: 1, placeholder: '≥1', name: 'count' }
        ], '平分红包，人人有份！');
    });

    // ── 专属红包按钮 ──
    const sfBtn = win.querySelector('#_xl_sf_btn');
    sfBtn.addEventListener('click', (e) => {
        e.stopPropagation();
        showRpConfirm(sfBtn, '专属红包', 'specify', [
            { label: '用户名', type: 'text', inputType: 'text', default: '', placeholder: '请输入用户名', name: 'recivers' },
            { label: '积分', type: 'number', inputType: 'number', min: 32, default: 32, placeholder: '≥32', name: 'money' },
            { label: '个数', type: 'number', inputType: 'number', min: 1, default: 1, placeholder: '≥1', name: 'count' }
        ], '试试看，这是给你的红包吗？');
    });

    // ── 上传文件按钮 ──
    const upfileBtn = win.querySelector('#_xl_upflie_btn');
    upfileBtn.addEventListener('click', (e) => {
        e.stopPropagation();
        sendMessage();
        // triggerFileUpload();
    });


    // ── 触发文件选择 ──
    function triggerFileUpload() {
        fileInput.value = '';
        fileInput.click();
    }

    // ── 处理文件上传 ──
    async function handleFileUpload(files) {
        if (!files || files.length === 0) return;

        const fileArr = Array.from(files);

        // 验证文件类型
        for (const file of fileArr) {
            if (!file.type.startsWith('image/')) {
                statusEl.textContent = `文件「${file.name}」不是图片类型，已跳过`;
                setTimeout(() => { statusEl.textContent = isPaused ? '已暂停' : '监听中'; }, 5000);
                return;
            }
        }

        // 验证文件大小（20MB）
        for (const file of fileArr) {
            if (file.size > 20 * 1024 * 1024) {
                statusEl.textContent = `文件「${file.name}」超过 20MB 限制`;
                setTimeout(() => { statusEl.textContent = isPaused ? '已暂停' : '监听中'; }, 5000);
                return;
            }
        }

        try {
            statusEl.textContent = `正在上传 ${fileArr.length} 张图片…`;
            // v3 上传流程：取票据 → 直传图床
            const urls = await uploadV3Images(fileArr);

            if (urls && urls.length) {
                // 上传成功：将图片 markdown 追加到输入框
                const mdImgs = urls.map(url => `![图片](${url})`).join('\n');
                const prev = msgInput.value.trim();
                msgInput.value = prev ? (prev + '\n' + mdImgs) : mdImgs;
                msgInput.focus();
                msgInput.selectionStart = msgInput.selectionEnd = msgInput.value.length;
                statusEl.textContent = `上传成功，已插入 ${urls.length} 张图片`;
                setTimeout(() => { statusEl.textContent = isPaused ? '已暂停' : '监听中'; }, 5000);
            } else {
                statusEl.textContent = '上传失败: 服务器返回异常';
            }
        } catch (err) {
            statusEl.textContent = '上传失败: ' + err.message;
        }
    }

    // file input change 事件
    fileInput.addEventListener('change', (e) => {
        handleFileUpload(e.target.files);
    });


    // 移除猜拳弹窗
    function removeRpsPopup() {
        document.querySelectorAll('.xl-rps-popup-container').forEach(el => el.remove());
    }

    // 显示猜拳手势选择
    function showGesturePicker(rpEl, oId) {
        if (!isPanelOpen) return;
        removeRpsPopup();
        const gestures = [
            { key: 'rock', emoji: '✊', label: '石头' },
            { key: 'paper', emoji: '✋', label: '布' },
            { key: 'scissors', emoji: '✌️', label: '剪刀' }
        ];
        let btnsHtml = '';
        gestures.forEach(g => {
            const val = rockPaperScissorsType[g.key].value;
            btnsHtml += `<div class="xl-rps-btn-wrap" data-gesture="${val}">
        <button class="xl-rps-btn" title="${g.label}">${g.emoji}</button>
        <div class="xl-rps-btn-label">${g.label}</div>
      </div>`;
    });
      const container = h(`<div class="xl-rps-popup-container" style="position:absolute;z-index:2147483647;top:0;left:0;width:100%;height:100%;">
      <div style="position:absolute;top:0;left:0;width:100%;height:100%;"></div>
    </div>`);
      const popup = h(`<div class="xl-rps-popup">${btnsHtml}</div>`);
      // 定位到红包元素上方（限制在窗口内）
      container.appendChild(popup);
      win.appendChild(container);
      var rpRect = rpEl.getBoundingClientRect();
      var wRect = win.getBoundingClientRect();
      var pTop = rpRect.top - wRect.top - 80;
      var pLeft = rpRect.left + rpRect.width / 2 - 84 - wRect.left;
      pTop = Math.max(4, Math.min(pTop, wRect.height - 80));
      pLeft = Math.max(4, Math.min(pLeft, wRect.width - 170));
      popup.style.top = pTop + 'px';
      popup.style.left = pLeft + 'px';

      // 点击背景关闭
      container.firstChild.addEventListener('click', () => container.remove());

      // 手势按钮点击
      popup.querySelectorAll('.xl-rps-btn-wrap').forEach(wrap => {
          wrap.addEventListener('click', (ev) => {
              ev.stopPropagation();
              const gesture = parseInt(wrap.dataset.gesture, 10);
              container.remove();
              rpEl.classList.add('xl-rp-opening');
              redPacketOpen({ oId, gesture });
              setTimeout(() => {
                  rpEl.classList.remove('xl-rp-opening');
                  if (redPacketMap[oId]) {
                      const rp = redPacketMap[oId];
                      const statusTextEl = rpEl.querySelector('.xl-rp-status');
                      if (statusTextEl) {
                          statusTextEl.textContent = `${rp.got || 0}/${rp.count}个`;
                      }
                  }
              }, 1500);
          });
      });
  }

    // 红包点击事件委托
    gridEl.addEventListener('click', (e) => {
        const rpEl = e.target.closest('.xl-redpacket');
        if (!rpEl) return;
        // if (rpEl.classList.contains('xl-rp-empty') || rpEl.classList.contains('xl-rp-opened')) return;
        const oId = rpEl.dataset.oid;
        const rpType = rpEl.dataset.type;
        if (!oId || isPacketOpen) return;

        // 移除已有的猜拳弹窗
        removeRpsPopup();

        // 所有红包（包括猜拳）点击直接打开，不传gesture
        // 猜拳红包的gesture只通过自动弹出的面板选择
        rpEl.classList.add('xl-rp-opening');
        redPacketOpen({ oId });
        setTimeout(() => {
            rpEl.classList.remove('xl-rp-opening');
            if (redPacketMap[oId]) {
                const rp = redPacketMap[oId];
                const statusTextEl = rpEl.querySelector('.xl-rp-status');
                if (statusTextEl) {
                    statusTextEl.textContent = `${rp.got || 0}/${rp.count}个`;
                }
            }
        }, 1500);
    });

    /* ══════════ 长按操作菜单（窗口内） ══════════ */

    let actionPopupEl = null;
    let actionTargetRow = null; // 当前高亮的行
    let longPressTimer = null;
    let longPressTriggered = false;
    const LONG_PRESS_MS = 500;

    function removeActionPopup() {
        if (actionPopupEl) { actionPopupEl.remove(); actionPopupEl = null; }
        if (actionTargetRow) { actionTargetRow.classList.remove('xl-row-action-target'); actionTargetRow = null; }
    }

    function showActionPopup(rowEl, msg) {
        removeActionPopup();

        // 高亮关联行
        rowEl.classList.add('xl-row-action-target');
        actionTargetRow = rowEl;

        // 计算相对于 win 的位置
        const winRect = win.getBoundingClientRect();
        const rowRect = rowEl.getBoundingClientRect();
        const gridRect = gridEl.getBoundingClientRect();

        // popup 宽高估算
        const popupW = 216;
        const popupH = 70;
        const gap = 8;

        // 行相对于 win 的坐标
        const relRowTop = rowRect.top - winRect.top;
        const relRowBottom = rowRect.bottom - winRect.top;
        const relRowCenter = relRowTop + rowRect.height / 2;

        // grid 可见区域相对于 win 的坐标
        const relGridTop = gridRect.top - winRect.top;
        const relGridBottom = gridRect.bottom - winRect.top;

        // 尝试放在行上方
        let top = relRowTop - popupH - gap;
        let arrowDir = 'xl-popup-above';

        // 如果上方空间不足（被 grid 顶部裁切或超出 win），放下方
        if (top < relGridTop + 4) {
            top = relRowBottom + gap;
            arrowDir = 'xl-popup-below';
            // 如果下方也被裁切，则贴在 grid 可见区域内
            if (top + popupH > relGridBottom - 4) {
                top = relGridBottom - popupH - 4;
                arrowDir = 'xl-popup-above';
            }
        }

        // 水平居中，限制在 grid 内
        let left = relRowCenter - popupW / 2;
        const gridLeft = gridRect.left - winRect.left;
        const gridRight = gridRect.right - winRect.right + winRect.width;
        left = Math.max(gridLeft + 4, Math.min(left, gridRight - popupW - 4));

        // 箭头水平位置：尽量指向行中心
        const arrowLeft = Math.max(14, Math.min(relRowCenter - left, popupW - 14));

        const popup = h(`<div class="xl-action-popup ${arrowDir}" style="top:${top}px;left:${left}px">
      <button class="xl-action-popup-btn" data-action="repeat">
        <span class="xl-ap-icon">🔁</span>
        <span class="xl-ap-label">复读</span>
      </button>
      <button class="xl-action-popup-btn" data-action="at">
        <span class="xl-ap-icon">@</span>
        <span class="xl-ap-label">艾特</span>
      </button>
    </div>`);

      // 让箭头指向行
      popup.style.setProperty('--arrow-left', arrowLeft + 'px');

      // 按钮事件
      popup.querySelectorAll('.xl-action-popup-btn').forEach(btn => {
          btn.addEventListener('click', (e) => {
              e.stopPropagation();
              const action = btn.dataset.action;
              if (action === 'repeat') repeatMessage(msg.content);
              else if (action === 'at') atUser(msg.userName);
              removeActionPopup();
          });
      });

      // 插入到 grid 容器内（保持在窗口中）
      gridEl.appendChild(popup);
      actionPopupEl = popup;

      // 修正箭头精确指向
      popup.querySelector(`.${arrowDir === 'xl-popup-above' ? 'xl-popup-above' : 'xl-popup-below'}`)
      && popup.style.setProperty('--arrow-offset', arrowLeft + 'px');
      // 设置 ::after 的 left
      const styleTag = document.createElement('style');
      styleTag.textContent = `.xl-action-popup::after{left:${arrowLeft}px;transform:translateX(0)}`;
      popup.appendChild(styleTag);
  }

    // 获取点击所在行对应的消息数据
    function getMsgFromRow(target) {
        const row = target.closest('.xl-row');
        if (!row) return null;
        const idx = parseInt(row.dataset.idx, 10);
        const msg = messages[idx];
        if (!msg) return null;
        return { row, msg };
    }

    // 不弹出操作菜单的消息类型
    const ACTION_BLOCKED_TYPES = new Set(['redPacket', 'music']);

    function isActionBlocked(msg) {
        return ACTION_BLOCKED_TYPES.has(msg.type);
    }

    // ── 全局点击关闭 ──
    document.addEventListener('click', (e) => {
        if (!actionPopupEl) return;
        // 点击的不是弹窗内部，则关闭
        if (!actionPopupEl.contains(e.target)) {
            removeActionPopup();
        }
    });

    // ── 鼠标长按 ──
    gridEl.addEventListener('mousedown', (e) => {
        if (e.button !== 0) return;
        if (e.target.closest('.xl-action-popup')) return;
        const hit = getMsgFromRow(e.target);
        if (!hit || isActionBlocked(hit.msg)) return;

        longPressTriggered = false;
        clearTimeout(longPressTimer);

        longPressTimer = setTimeout(() => {
            longPressTriggered = true;
            showActionPopup(hit.row, hit.msg);
        }, LONG_PRESS_MS);
    });

    gridEl.addEventListener('mousemove', () => {
        clearTimeout(longPressTimer);
    });

    gridEl.addEventListener('mouseup', () => {
        clearTimeout(longPressTimer);
    });

    // ── 右键直接弹出 ──
    gridEl.addEventListener('contextmenu', (e) => {
        const hit = getMsgFromRow(e.target);
        if (!hit || isActionBlocked(hit.msg)) return;
        e.preventDefault();
        clearTimeout(longPressTimer);
        showActionPopup(hit.row, hit.msg);
    });

    // ── 触屏长按 ──
    let touchStartPos = null;

    gridEl.addEventListener('touchstart', (e) => {
        if (e.target.closest('.xl-action-popup')) return;
        const hit = getMsgFromRow(e.target);
        if (!hit || isActionBlocked(hit.msg)) return;

        const touch = e.touches[0];
        touchStartPos = { x: touch.clientX, y: touch.clientY };
        longPressTriggered = false;
        clearTimeout(longPressTimer);

        longPressTimer = setTimeout(() => {
            longPressTriggered = true;
            showActionPopup(hit.row, hit.msg);
            if (navigator.vibrate) navigator.vibrate(30);
        }, LONG_PRESS_MS);
    }, { passive: true });

    gridEl.addEventListener('touchmove', (e) => {
        if (!touchStartPos) return;
        const touch = e.touches[0];
        const dx = Math.abs(touch.clientX - touchStartPos.x);
        const dy = Math.abs(touch.clientY - touchStartPos.y);
        if (dx > 10 || dy > 10) {
            clearTimeout(longPressTimer);
            touchStartPos = null;
        }
    }, { passive: true });

    gridEl.addEventListener('touchend', () => {
        clearTimeout(longPressTimer);
        touchStartPos = null;
        if (longPressTriggered) longPressTriggered = false;
    });

    // 长按触发后拦截 click
    gridEl.addEventListener('click', (e) => {
        if (longPressTriggered) {
            e.stopPropagation();
            e.preventDefault();
            longPressTriggered = false;
        }
    }, true);

    // 图片双击放大预览
    gridEl.addEventListener('dblclick', (e) => {
        const img = e.target.closest('.xl-cell-c img');
        if (!img || img.classList.contains('xl-img-hidden')) return;
        e.preventDefault();
        const src = img.src || img.dataset.src || '';
        if (!src) return;
        const overlay = h(`<div class="xl-img-overlay">
      <button class="xl-img-close">✕</button>
      <img src="${src}" />
    </div>`);
      const close = () => overlay.remove();
      overlay.querySelector('.xl-img-close').addEventListener('click', close);
      overlay.addEventListener('click', (ev) => { if (ev.target === overlay) close(); });
      document.addEventListener('keydown', function onKey(ev) {
          if (ev.key === 'Escape') { close(); document.removeEventListener('keydown', onKey); }
      });
      document.body.appendChild(overlay);
  });

    /* ══════════ 渲染 ══════════ */
    function esc(s) {
        const d = document.createElement('span');
        d.textContent = s;
        return d.innerHTML;
    }

    // 渲染一行消息
    function renderRow(msg, idx, isNew) {
        const row = h(`
      <div class="xl-row${isNew ? ' xl-row-new' : ''}" data-idx="${idx}">
        <div class="xl-rn">${idx + 1}</div>
        <div class="xl-cell xl-cell-a">${esc(msg.time)}</div>
        <div class="xl-cell xl-cell-b">${esc(msg.sender)}</div>
        <div class="xl-cell xl-cell-c">${msg.contentHtml || esc(msg.content)}</div>
        <div class="xl-cell xl-cell-d"></div>
        <div class="xl-cell xl-cell-d"></div>
        <div class="xl-cell xl-cell-d"></div>
        <div class="xl-cell xl-cell-d"></div>
        <div class="xl-cell xl-cell-d"></div>
        <div class="xl-cell xl-cell-d"></div>
        <div class="xl-cell xl-cell-d"></div>
        <div class="xl-cell xl-cell-d"></div>
      </div>
    `);
      row.addEventListener('click', () => {
          gridEl.querySelectorAll('.xl-row').forEach(r => r.classList.remove('xl-selected'));
          row.classList.add('xl-selected');
      });
      return row;
  }

    // 渲染所有消息
    function renderAll() {
        gridEl.innerHTML = '';
        if (messages.length === 0) {
            gridEl.innerHTML = `<div style="text-align:center;color:#aaa;padding:60px 20px;font-size:12px;">
        暂无消息，等待聊天室新消息…
      </div>`;
    } else {
        messages.forEach((m, i) => {
            gridEl.appendChild(renderRow(m, i, false));
        });
        applyImageVisibility();
    }
      statEl.textContent = `共 ${messages.length} 行`;
      cellRef.textContent = 'C ' + (messages.length + 1);
      if (autoScroll) gridEl.scrollTop = gridEl.scrollHeight;
  }

    // 追加一行消息
    function appendRow(msg) {
        // 移除占位
        if (messages.length === 1) gridEl.innerHTML = '';
        const idx = messages.length - 1;
        const row = renderRow(msg, idx, true);
        gridEl.appendChild(row);
        // 对新行应用图片显示/隐藏设置
        if (!xlSettings.showImages) {
            row.querySelectorAll('.xl-cell-c img').forEach(img => {
                img.classList.add('xl-img-hidden');
                img.style.display = 'none';
                if (!img.nextElementSibling || !img.nextElementSibling.classList.contains('xl-img-placeholder')) {
                    const span = document.createElement('span');
                    span.className = 'xl-img-placeholder';
                    span.textContent = '[图片]';
                    img.parentNode.insertBefore(span, img.nextSibling);
                }
            });
        }
        statEl.textContent = `共 ${messages.length} 行`;
        cellRef.textContent = 'C ' + (messages.length + 1);
        if (autoScroll) gridEl.scrollTop = gridEl.scrollHeight;
    }

    // 原地更新一行消息（红包领取进度等）
    function updateRow(idx, msg) {
        const row = renderRow(msg, idx, false);
        const old = gridEl.querySelector(`.xl-row[data-idx="${idx}"]`);
        if (old) old.replaceWith(row);
        else gridEl.appendChild(row);
        applyImageVisibility();
    }

    // 复读：直接发送原消息的 markdown 内容
    async function repeatMessage(md) {
        if (!md) {
            statusEl.textContent = '该消息不支持复读';
            setTimeout(() => { statusEl.textContent = isPaused ? '已暂停' : '监听中'; }, 3000);
            return;
        }
        try {
            await sendChatMessage(md);
            statusEl.textContent = '已复读';
            setTimeout(() => { statusEl.textContent = isPaused ? '已暂停' : '监听中'; }, 3000);
        } catch (err) {
            statusEl.textContent = '复读失败: ' + err.message;
        }
    }

    // 引用：将原消息以 blockquote 格式插入到输入框，让用户补充回复
    function quoteMessage(md) {
        if (!md) {
            statusEl.textContent = '该消息不支持引用';
            setTimeout(() => { statusEl.textContent = isPaused ? '已暂停' : '监听中'; }, 3000);
            return;
        }
        const quoted = md.split('\n').map(l => '> ' + l).join('\n');
        const prev = msgInput.value.trim();
        msgInput.value = quoted + '\n\n' + prev;
        msgInput.focus();
        // 将光标移到末尾
        msgInput.selectionStart = msgInput.selectionEnd = msgInput.value.length;
        statusEl.textContent = '已引用到输入框，请补充回复内容';
        setTimeout(() => { statusEl.textContent = isPaused ? '已暂停' : '监听中'; }, 3000);
    }

    // 艾特：在输入框插入 "@userName"，并将光标移到末尾
    function atUser(userName) {
        _xl_msg_input
        if (!userName) return;
        const prev = msgInput.value.trim();
        msgInput.value = '@' + userName + ' ' + (prev || '');
        msgInput.focus();
        msgInput.selectionStart = msgInput.selectionEnd = msgInput.value.length;
        statusEl.textContent = '已添加 @' + userName;
        setTimeout(() => { statusEl.textContent = isPaused ? '已暂停' : '监听中'; }, 3000);
    }

    /* ══════════ 核心：实时监听 ══════════ */

    // 处理聊天室消息
    function processChatItem(item) {
        const parsed = parseMessage(item);
        const { sender, time, content, contentHtml, isRpsPacket, oId, userName, type } = parsed;
        if (!content && !contentHtml) return;

        const msg = { time, sender, content, contentHtml, userName, type, oId };

        // 同一消息（如红包被领取触发 chat.message.updated）原地更新，避免重复成行
        const existingIdx = oId ? messages.findIndex(m => m.oId === oId) : -1;
        if (existingIdx >= 0) {
            messages[existingIdx] = msg;
            updateRow(existingIdx, msg);
        } else {
            messages.push(msg);
            appendRow(msg);
        }

        // 猜拳红包自动弹出手势选择（非自己发的、未领完的）
        if (isRpsPacket && oId) {
            const rp = redPacketMap[oId];
            const myName = accountInfo ? accountInfo.userName : '';
            const isMine = rp && rp.userName && myName && rp.userName === myName;
            const isEmpty = rp && rp.got >= rp.count;
            if (!isMine && !isEmpty) {
                // 等待DOM渲染完成后定位
                requestAnimationFrame(() => {
                    const rpEl = gridEl.querySelector(`.xl-redpacket[data-oid="${oId}"]`);
                    if (rpEl) showGesturePicker(rpEl, oId);
                });
            }
        }
    }

    /* ══════════ 事件绑定 ══════════ */

    // 打开窗口
    fab.addEventListener('click', () => {
        if (fab.dataset.dragged === '1') { fab.dataset.dragged = ''; return; }
        fab.classList.add('_xl_hide');
        fab.classList.remove('_xl_blink');
        win.classList.add('_xl_open');
        isPanelOpen = true;
        win.style.opacity = xlSettings.opacity / 100;
        restoreWinPos();
        renderAll();
    });

    // 关闭 / 最小化
    function closeWin() {
        win.classList.remove('_xl_open');
        win.style.opacity = ''; // 清除内联透明度，让 CSS opacity:0 生效
        if (isFull) { win.classList.remove('_xl_full'); isFull = false; maxBtn.innerHTML = I.max; document.body.style.overflow = ''; }
        isPanelOpen = false;
        setTimeout(() => fab.classList.remove('_xl_hide'), 200);
    }
    win.querySelector('#_xl_min').addEventListener('click', closeWin);
    win.querySelector('#_xl_close').addEventListener('click', closeWin);

    // 全屏
    maxBtn.addEventListener('click', () => {
        isFull = !isFull;
        if (isFull) {
            // 进入全屏前保存当前位置，清除inline样式让CSS !important生效
            win.removeAttribute('style');
            win.classList.add('_xl_full');
            // 隐藏页面滚动条，防止覆盖grid滚动条
            document.body.style.overflow = 'hidden';
        } else {
            win.classList.remove('_xl_full');
            // 恢复页面滚动条
            document.body.style.overflow = '';
            // 恢复透明度
            win.style.opacity = xlSettings.opacity / 100;
            // 恢复保存的位置
            restoreWinPos();
        }
        maxBtn.innerHTML = isFull ? I.rest : I.max;
        if (autoScroll) gridEl.scrollTop = gridEl.scrollHeight;
    });

    //暂停/播放
    pauseBtn.addEventListener('click', async () => {
        isPaused = !isPaused;
        pauseBtn.textContent = isPaused ? '▶' : '⏸';
        liveLabel.textContent = isPaused ? '已暂停' : '⚫︎';
        liveLabel.style.color = isPaused ? '#999' : '#217346';
        statusEl.textContent = isPaused ? '已暂停' : '监听中';
        if (isPaused) {
            stopChatroom();
        } else {
            getHistoryMessages();
            startLisentChatroom();
        }
    });

    // 清空
    clearBtn.addEventListener('click', () => {
        messages = [];
        renderAll();
        statusEl.textContent = '已清空';
    });

    // 自动滚动
    scrollBtn.addEventListener('click', () => {
        autoScroll = !autoScroll;
        scrollBtn.style.opacity = autoScroll ? '1' : '.4';
        if (autoScroll) gridEl.scrollTop = gridEl.scrollHeight;
    });

    /* ══════════ 设置管理 ══════════ */
    const settingsBtn = win.querySelector('#_xl_settings_btn');
    const settingsPopup = win.querySelector('#_xl_settings_popup');
    const opacitySlider = win.querySelector('#_xl_opacity_slider');
    const opacityVal = win.querySelector('#_xl_opacity_val');
    const imgToggle = win.querySelector('#_xl_img_toggle');
    const rpToggle = win.querySelector('#_xl_rp_toggle');

    // 默认配置
    let xlSettings = { opacity: 100, showImages: true, showRedPacket: true, shortcutsConfig: null, randomRpsConfig: null, hotkeys: null };

    // 从 cloudStorage 加载配置
    async function loadSettings() {
        try {
            const raw = await cloudStorage.getItem('xl_settings');
            if (raw) {
                const saved = JSON.parse(raw);
                xlSettings = { ...xlSettings, ...saved };
            }
        } catch (e) { /* ignore */ }
        // 应用到 UI（仅面板已打开时设置透明度，否则不覆盖 CSS 的 opacity:0）
        opacitySlider.value = xlSettings.opacity;
        opacityVal.textContent = xlSettings.opacity + '%';
        if (isPanelOpen) win.style.opacity = xlSettings.opacity / 100;
        if (xlSettings.showImages) {
            imgToggle.classList.add('xl-toggle-on');
        } else {
            imgToggle.classList.remove('xl-toggle-on');
        }
        // 红包显示
        if (rpToggle) rpToggle.classList.toggle('xl-toggle-on', xlSettings.showRedPacket !== false);
        // 快捷语
        if (xlSettings.shortcutsConfig) shortcutsConfig = xlSettings.shortcutsConfig;
        else shortcutsConfig = defaultShortcutsConfig;
        // 随机出拳
        if (xlSettings.randomRpsConfig) randomRpsConfig = { ...randomRpsConfig, ...xlSettings.randomRpsConfig };
        // 快捷键
        if (!xlSettings.hotkeys) xlSettings.hotkeys = JSON.parse(JSON.stringify(defaultHotkeys));
        applyImageVisibility();
        applyRedPacketVisibility();
        // 刷新设置面板UI
        renderScList();
        applyRpsConfig();
        renderHotkeyInputs();
    }

    // 保存配置到 cloudStorage
    async function saveSettings() {
        try {
            await cloudStorage.setItem('xl_settings', JSON.stringify(xlSettings));
        } catch (e) {
            /* ignore */
            console.error(e);
        }
    }

    // ── 快捷键工具函数 ──
    // 格式化快捷键配置为可读字符串
    function hotkeyToString(hk) {
        if (!hk || !hk.key) return '';
        let parts = [];
        if (hk.ctrl) parts.push('Ctrl');
        if (hk.alt) parts.push('Alt');
        if (hk.shift) parts.push('Shift');
        parts.push(hk.key.toUpperCase());
        return parts.join('+');
    }

    // 解析键盘事件为快捷键配置对象
    function eventToHotkey(e) {
        return { ctrl: e.ctrlKey, alt: e.altKey, shift: e.shiftKey, key: e.key.toLowerCase() };
    }

    // 比较两个快捷键配置是否相同
    function isSameHotkey(a, b) {
        if (!a || !b) return false;
        return !!(a.ctrl) === !!(b.ctrl) && !!(a.alt) === !!(b.alt) && !!(a.shift) === !!(b.shift) && a.key === b.key;
    }

    // 渲染快捷键输入框
    function renderHotkeyInputs() {
        const smallInput = win.querySelector('#_xl_hotkey_small');
        if (smallInput && xlSettings.hotkeys) {
            smallInput.value = hotkeyToString(xlSettings.hotkeys.toggleSmall) || '';
            smallInput.placeholder = '点击录制按键';
        }
    }

    // 快捷键录制状态
    let recordingTarget = null; // 'small' | null

    // 切换小框显示/隐藏
    function toggleSmallWindow() {
        if (isPanelOpen) {
            closeWin();
        } else {
            fab.classList.add('_xl_hide');
            fab.classList.remove('_xl_blink');
            win.classList.add('_xl_open');
            isPanelOpen = true;
            win.style.opacity = xlSettings.opacity / 100;
            restoreWinPos();
            renderAll();
        }
    }

    // 全局键盘快捷键监听
    document.addEventListener('keydown', (e) => {
        // 如果正在录制快捷键，不处理
        if (recordingTarget) return;

        // 忽略在输入框中的快捷键
        const tag = e.target.tagName;
        if (tag === 'INPUT' || tag === 'TEXTAREA' || e.target.isContentEditable) return;

        const hk = xlSettings.hotkeys || defaultHotkeys;

        // 检查 Ctrl+Alt+M（显示/隐藏小框）
        if (isSameHotkey(eventToHotkey(e), hk.toggleSmall)) {
            e.preventDefault();
            toggleSmallWindow();
            return;
        }
    });

    // ── 快捷键输入框录制事件 ──
    function setupHotkeyInputs() {
        const smallInput = win.querySelector('#_xl_hotkey_small');
        const fullInput = win.querySelector('#_xl_hotkey_full');
        const resetBtn = win.querySelector('#_xl_hotkey_reset_btn');

        if (smallInput) {
            smallInput.addEventListener('click', () => {
                if (recordingTarget === 'small') {
                    // 取消录制
                    recordingTarget = null;
                    smallInput.style.borderColor = '#ddd';
                    renderHotkeyInputs();
                    return;
                }
                recordingTarget = 'small';
                smallInput.value = '请按键...';
                smallInput.style.borderColor = '#217346';
            });
        }

        // 快捷键录制 - 按键捕获
        document.addEventListener('keydown', (e) => {
            if (!recordingTarget) return;
            e.preventDefault();
            e.stopPropagation();

            // ESC 取消录制
            if (e.key === 'Escape') {
                recordingTarget = null;
                renderHotkeyInputs();
                if (smallInput) smallInput.style.borderColor = '#ddd';
                return;
            }

            // 忽略单独的修饰键
            if (['Control', 'Alt', 'Shift', 'Meta'].includes(e.key)) return;

            const hk = eventToHotkey(e);
            if (recordingTarget === 'small') {
                xlSettings.hotkeys.toggleSmall = hk;
                if (smallInput) {
                    smallInput.value = hotkeyToString(hk);
                    smallInput.style.borderColor = '#ddd';
                }
            }
            recordingTarget = null;
        }, true);

        // 恢复全部默认设置
        if (resetBtn) {
            resetBtn.addEventListener('click', (e) => {
                e.stopPropagation();
                // 恢复默认值
                xlSettings.opacity = 100;
                xlSettings.showImages = true;
                xlSettings.showRedPacket = true;
                xlSettings.shortcutsConfig = null;
                xlSettings.randomRpsConfig = null;
                xlSettings.hotkeys = JSON.parse(JSON.stringify(defaultHotkeys));
                shortcutsConfig = JSON.parse(JSON.stringify(defaultShortcutsConfig));
                randomRpsConfig = { enabled: false, minMoney: 256 };
                // 更新 UI
                opacitySlider.value = 100;
                opacityVal.textContent = '100%';
                win.style.opacity = 1;
                imgToggle.classList.add('xl-toggle-on');
                rpToggle.classList.add('xl-toggle-on');
                applyImageVisibility();
                applyRedPacketVisibility();
                renderScList();
                applyRpsConfig();
                renderHotkeyInputs();
            });
        }
    }

    // 初始化快捷键输入框事件
    setupHotkeyInputs();

    // 应用图片显示/隐藏（实时切换所有已有行）
    function applyImageVisibility() {
        const imgs = gridEl.querySelectorAll('.xl-cell-c img');
        imgs.forEach(img => {
            if (xlSettings.showImages) {
                // 还原图片
                img.classList.remove('xl-img-hidden');
                img.style.display = '';
                // 移除旁边的占位符
                const ph = img.parentNode && img.parentNode.querySelector('.xl-img-placeholder');
                if (ph) ph.remove();
            } else {
                // 隐藏图片并插入占位符
                img.classList.add('xl-img-hidden');
                img.style.display = 'none';
                // 如果还没有占位符则插入一个
                if (!img.nextElementSibling || !img.nextElementSibling.classList.contains('xl-img-placeholder')) {
                    const span = document.createElement('span');
                    span.className = 'xl-img-placeholder';
                    span.textContent = '[图片]';
                    img.parentNode.insertBefore(span, img.nextSibling);
                }
            }
        });
    }

    // 应用红包显示/隐藏（实时切换所有已有行）
    function applyRedPacketVisibility() {
        if (xlSettings.showRedPacket === false) {
            // 隐藏红包：将所有红包元素替换为文本
            gridEl.querySelectorAll('.xl-redpacket').forEach(rpEl => {
                const oId = rpEl.dataset.oid;
                const rpType = rpEl.dataset.type;
                const typeCn = redPacketTypeCn[rpType] || '普通';
                const span = document.createElement('span');
                span.className = 'xl-rp-hidden-text';
                span.dataset.oid = oId;
                span.dataset.type = rpType;
                span.style.cssText = 'color:#e74c3c;font-weight:600';
                span.textContent = '【' + typeCn + '红包】';
                rpEl.parentNode.replaceChild(span, rpEl);
            });
        } else {
            // 显示红包：将文本还原为红包元素
            gridEl.querySelectorAll('.xl-rp-hidden-text').forEach(span => {
                const oId = span.dataset.oid;
                const rp = redPacketMap[oId];
                if (rp) {
                    const wrapper = document.createElement('div');
                    wrapper.innerHTML = buildRedPacketHtml(rp, oId);
                    span.parentNode.replaceChild(wrapper.firstChild, span);
                } else {
                    // 无红包数据，保留文本
                    const typeCn = redPacketTypeCn[span.dataset.type] || '普通';
                    span.textContent = '【' + typeCn + '红包】';
                }
            });
        }
    }

    // 设置按钮：切换面板
    settingsBtn.addEventListener('click', (e) => {
        e.stopPropagation();
        settingsPopup.classList.toggle('xl-settings-open');
    });

    // 点击外部关闭设置面板
    document.addEventListener('click', (e) => {
        if (!settingsPopup.contains(e.target) && e.target !== settingsBtn) {
            settingsPopup.classList.remove('xl-settings-open');
        }
    });
    // 阻止面板内部点击冒泡关闭
    settingsPopup.addEventListener('click', (e) => e.stopPropagation());

    // 透明度滑块
    opacitySlider.addEventListener('input', () => {
        const v = parseInt(opacitySlider.value, 10);
        opacityVal.textContent = v + '%';
        win.style.opacity = v / 100;
        xlSettings.opacity = v;
    });

    // 图片开关
    imgToggle.addEventListener('click', () => {
        xlSettings.showImages = !xlSettings.showImages;
        imgToggle.classList.toggle('xl-toggle-on', xlSettings.showImages);
        applyImageVisibility();
    });

    // 红包显示开关
    rpToggle.addEventListener('click', () => {
        xlSettings.showRedPacket = !(xlSettings.showRedPacket !== false);
        rpToggle.classList.toggle('xl-toggle-on', xlSettings.showRedPacket);
        applyRedPacketVisibility();
    });

    // 统一保存设置按钮
    const settingsSaveBtn = win.querySelector('#_xl_settings_save_btn');
    if (settingsSaveBtn) {
        settingsSaveBtn.addEventListener('click', async (e) => {
            e.stopPropagation();
            await saveSettings();
            settingsSaveBtn.textContent = '已保存✓';
            settingsSaveBtn.style.background = '#4caf50';
            setTimeout(() => {
                settingsSaveBtn.textContent = '保存设置';
                settingsSaveBtn.style.background = '#217346';
            }, 1500);
        });
    }

    // 初始化时加载配置
    loadSettings();

    // ── 通知角标 & 私信角标 ──
    const noticesBtn = win.querySelector('#_xl_notices_btn');
    const premsgsBtn = win.querySelector('#_xl_premsgs_btn');
    let noticeBadge = null;
    let premsgBadge = null;

    function createBadge(anchor, count) {
        let badge = anchor.querySelector('.xl-badge');
        if (!badge) {
            badge = document.createElement('span');
            badge.className = 'xl-badge';
            anchor.style.position = 'relative';
            anchor.appendChild(badge);
        }
        badge.textContent = count > 99 ? '99+' : count;
        badge.style.display = count > 0 ? '' : 'none';
        return badge;
    }

    function updateNoticeBadge() {
        noticeBadge = createBadge(noticesBtn, noticeUnreadCnt);
    }
    function updatePremsgBadge() {
        premsgBadge = createBadge(premsgsBtn, unreadPreMgsList ? unreadPreMgsList.length : 0);
    }

    // ── 通知面板 ──
    let noticePanel = null;
    let noticePanelMode = 'types'; // 'types' | 'detail'

    function removeNoticePanel() {
        if (noticePanel) { noticePanel.remove(); noticePanel = null; noticePanelMode = 'types'; }
    }

    function renderNoticeTypes() {
        const body = noticePanel.querySelector('.xl-notice-body');
        body.innerHTML = '';
        noticePanelMode = 'types';
        const header = noticePanel.querySelector('.xl-notice-header');
        header.querySelector('span').textContent = '通知';

        const apiKeyMap = {
            'at': 'unreadAtNotificationCnt',
            'commented': 'unreadCommentedNotificationCnt',
            'reply': 'unreadReplyNotificationCnt',
            'point': 'unreadPointNotificationCnt',
            'following': 'unreadFollowingNotificationCnt',
            'sys-announce': 'unreadSysAnnounceNotificationCnt',
            'broadcast': 'unreadBroadcastNotificationCnt',
        };
        const allTypes = Object.keys(noticeTypeDisplayMap);
        let hasUnread = false;
        allTypes.forEach(key => {
            const info = noticeTypeDisplayMap[key];
            const apiKey = apiKeyMap[key];
            const cnt = apiKey && noticeUnReadResult && noticeUnReadResult[apiKey] ? noticeUnReadResult[apiKey] : 0;
            if (cnt <= 0) return;
            hasUnread = true;
            const item = document.createElement('div');
            item.className = 'xl-notice-type-item';
            item.innerHTML = `<span class="xl-notice-type-icon">${info.icon}</span><span class="xl-notice-type-label">${esc(info.label)}</span><span class="xl-notice-type-cnt">${cnt}</span>`;
            item.addEventListener('click', (e) => {
                e.stopPropagation();
                renderNoticeDetail(key, info);
            });
            body.appendChild(item);
        });
        if (!hasUnread) {
            body.innerHTML = '<div class="xl-notice-empty">暂无未读通知</div>';
        }
    }

    async function renderNoticeDetail(typeKey, info) {
        await loadUnreadNoticeTypeList(typeKey)
        const body = noticePanel.querySelector('.xl-notice-body');
        body.innerHTML = '';
        noticePanelMode = 'detail';
        const header = noticePanel.querySelector('.xl-notice-header');
        header.querySelector('span').textContent = info.label;

        // 返回按钮
        const backBtn = document.createElement('button');
        backBtn.className = 'xl-notice-detail-back';
        backBtn.textContent = '← 返回通知列表';
        backBtn.addEventListener('click', (e) => { e.stopPropagation(); renderNoticeTypes(); });
        body.appendChild(backBtn);

        // 加载列表
        try {
            if (unreadNoticeTypeList.length > 0) {
                unreadNoticeTypeList.forEach(item => {
                    const el = document.createElement('div');
                    el.className = 'xl-notice-detail-item';
                    const title = item.title || info.label;
                    const rawContent = item.description || (item.descriptionHtml || '').replace(/<[^>]*>/g, '');
                    const cleanContent = (rawContent || '').substring(0, 120);
                    const timeStr = formatDateTime(item.createdAt);
                    el.innerHTML = `<div class="xl-notice-detail-title">${esc(title)}</div><div>${esc(cleanContent)}</div>${timeStr ? '<div class="xl-notice-detail-time">' + esc(timeStr) + '</div>' : ''}`;
                    const articleId = item.article && item.article.id;
                    const targetUrl = item.url;
                    if (articleId) {
                        el.style.cursor = 'pointer';
                        el.addEventListener('click', () => {
                            showArticleDetail(String(articleId));
                        });
                    } else if (targetUrl) {
                        el.style.cursor = 'pointer';
                        el.addEventListener('click', () => {
                            window.open(targetUrl, '_blank');
                        });
                    }
                    body.appendChild(el);
                });
                // 标记已读
                try {
                    await makeReadNotice(typeKey)
                } catch (e) {
                }
                await loadNoticeUnreadCount();
            } else {
                const emptyEl = document.createElement('div');
                emptyEl.className = 'xl-notice-empty';
                emptyEl.textContent = '暂无通知';
                body.appendChild(emptyEl);
            }
        } catch (err) {
            const errEl = document.createElement('div');
            errEl.className = 'xl-notice-empty';
            errEl.textContent = '加载失败: ' + (err.message || err);
            body.appendChild(errEl);
        }
    }

    function showNoticePanel() {
        if (!isPanelOpen) return;
        removeNoticePanel();
        const panel = document.createElement('div');
        panel.className = 'xl-notice-panel';
        panel.innerHTML = `<div class="xl-notice-header"><span>通知</span><div class="xl-notice-header-btns"><button class="xl-notice-readall">一键已读</button><button class="xl-notice-close">✕</button></div></div><div class="xl-notice-body"></div>`;

        const rect = noticesBtn.getBoundingClientRect();
        win.appendChild(panel);
        noticePanel = panel;
        // 定位到按钮下方（限制在窗口内，右对齐）
        var wRect = win.getBoundingClientRect();
        var pTop = rect.bottom + 4 - wRect.top;
        var pRight = wRect.right - rect.right;
        pTop = Math.max(4, Math.min(pTop, wRect.height - (panel.offsetHeight || 400)));
        pRight = Math.max(4, pRight);
        panel.style.top = pTop + 'px';
        panel.style.right = pRight + 'px';

        // 一键已读
        panel.querySelector('.xl-notice-readall').addEventListener('click', async (e) => {
            e.stopPropagation();
            try { await readAllNotice(); } catch (err) { }
            noticeUnreadCnt = 0;
            if (noticeUnReadResult) Object.keys(noticeUnReadResult).forEach(k => noticeUnReadResult[k] = 0);
            updateNoticeBadge();
            renderNoticeTypes();
        });

        // 关闭
        panel.querySelector('.xl-notice-close').addEventListener('click', (e) => { e.stopPropagation(); removeNoticePanel(); });
        panel.addEventListener('click', (e) => e.stopPropagation());

        renderNoticeTypes();
    }

    noticesBtn.addEventListener('click', (e) => {
        e.stopPropagation();
        removePremsgPanel();
        if (noticePanel) { removeNoticePanel(); } else { showNoticePanel(); }
    });

    document.addEventListener('click', (e) => {
        if (!noticePanel) return;
        if (!noticePanel.contains(e.target) && !noticesBtn.contains(e.target)) removeNoticePanel();
    });

    // ── 私信面板 ──
    let premsgPanel = null;

    function removePremsgPanel() {
        if (premsgPanel) { premsgPanel.remove(); premsgPanel = null; }
    }

    function showPremsgPanel() {
        if (!isPanelOpen) return;
        removePremsgPanel();
        const panel = document.createElement('div');
        panel.className = 'xl-premsg-panel';
        panel.innerHTML = `<div class="xl-premsg-header"><span>私信</span><button class="xl-premsg-close">✕</button></div><div class="xl-premsg-body"></div>`;

        const body = panel.querySelector('.xl-premsg-body');
        if (!chatUnreadList || chatUnreadList.length === 0) {
            body.innerHTML = '<div class="xl-premsg-empty">暂无私信消息</div>';
        } else {
            chatUnreadList.forEach(item => {
                const el = document.createElement('div');
                el.className = 'xl-premsg-item';
                const avatar = item.receiverAvatar;
                const name = item.receiverUserName || item.receiverName || item.senderName || item.userName || '未知用户';
                const preview = (item.content || item.preview || item.lastMessage || '').replace(/<[^>]*>/g, '').substring(0, 80);
                const time = item.time || item.updateTime || '';
                const unreadCnt = item.unreadCount || 0;
                el.innerHTML = `${avatar ? '<img class="xl-premsg-item-avatar" src="' + esc(avatar) + '" />' : ''}<div class="xl-premsg-item-info"><div class="xl-premsg-item-name">${esc(name)}</div><div class="xl-premsg-item-preview">${esc(preview) || '暂无内容'}</div>${time ? '<div class="xl-premsg-item-time">' + esc(time) + '</div>' : ''}</div><div class="xl-premsg-item-right">${unreadCnt > 0 ? '<span class="xl-premsg-item-badge">' + (unreadCnt > 99 ? '99+' : unreadCnt) + '</span>' : ''}<button class="xl-premsg-item-close" title="标记已读">✕</button></div>`;
                // 点击内容区域跳转到私信页面
                el.addEventListener('click', (e) => {
                    if (e.target.closest('.xl-premsg-item-close')) return;
                    window.open('https://fishpi.cn/chat', '_blank');
                });
                // X按钮标记已读
                const closeBtn = el.querySelector('.xl-premsg-item-close');
                if (closeBtn && item.peerId) {
                    closeBtn.addEventListener('click', async (e) => {
                        e.stopPropagation();
                        try {
                            await v3Fetch('/me/conversations/' + item.peerId + '/read', {
                                method: 'POST',
                                headers: { 'Idempotency-Key': genIdempotencyKey('premsg-read') },
                                body: '{}'
                            });
                        } catch (err) { }
                        await loadUnreadPreMgsList();
                        showPremsgPanel();
                    });
                }
                body.appendChild(el);
            });
        }

        const rect = premsgsBtn.getBoundingClientRect();
        win.appendChild(panel);
        premsgPanel = panel;
        // 定位到按钮下方（限制在窗口内，右对齐）
        var wRect = win.getBoundingClientRect();
        var pTop = rect.bottom + 4 - wRect.top;
        var pRight = wRect.right - rect.right;
        pTop = Math.max(4, Math.min(pTop, wRect.height - (panel.offsetHeight || 400)));
        pRight = Math.max(4, pRight);
        panel.style.top = pTop + 'px';
        panel.style.right = pRight + 'px';

        panel.querySelector('.xl-premsg-close').addEventListener('click', (e) => { e.stopPropagation(); removePremsgPanel(); });
        panel.addEventListener('click', (e) => e.stopPropagation());
    }

    premsgsBtn.addEventListener('click', (e) => {
        e.stopPropagation();
        removeNoticePanel();
        if (premsgPanel) { removePremsgPanel(); } else { showPremsgPanel(); }
    });

    document.addEventListener('click', (e) => {
        if (!premsgPanel) return;
        if (!premsgPanel.contains(e.target) && !premsgsBtn.contains(e.target)) removePremsgPanel();
    });

    // 初始更新角标
    setTimeout(() => { updateNoticeBadge(); updatePremsgBadge(); }, 2000);

    // 发送消息
    async function sendMessage() {
        const text = msgInput.value.trim();
        if (!text) return;
        try {
            await sendChatMessage(text);
            msgInput.value = '';
            statusEl.textContent = '消息已发送';
            setTimeout(() => { statusEl.textContent = isPaused ? '已暂停' : '监听中'; }, 5000);
        } catch (err) {
            statusEl.textContent = '发送失败: ' + err.message;
        }
    }

    // Enter 键发送
    msgInput.addEventListener('keydown', (e) => {
        if (e.key === 'Enter' && !e.shiftKey) {
            e.preventDefault();
            sendMessage();
        }
    });

    // 拖拽 & 位置保存
    async function saveWinPos() {
        try {
            const r = win.getBoundingClientRect();
            await cloudStorage.setItem('xl_win_pos', JSON.stringify({ left: r.left, top: r.top }));
        } catch (e) { /* ignore */ }
    }
    async function restoreWinPos() {
        try {
            const raw = await cloudStorage.getItem('xl_win_pos');
            if (raw) {
                const pos = JSON.parse(raw);
                win.style.left = pos.left + 'px';
                win.style.top = pos.top + 'px';
                win.style.right = 'auto';
                win.style.bottom = 'auto';
            }
        } catch (e) { /* ignore */ }
    }
    (function () {
        const header = win.querySelector('#_xl_drag');
        let on = false, sx, sy, ox, oy;
        header.addEventListener('mousedown', e => {
            if (isFull) return;
            if (e.target.closest('.xl-titlebar-btns')) return;
            on = true; sx = e.clientX; sy = e.clientY;
            const r = win.getBoundingClientRect();
            ox = r.left; oy = r.top; e.preventDefault();
        });
        document.addEventListener('mousemove', e => {
            if (!on) return;
            const nx = ox + e.clientX - sx;
            const ny = oy + e.clientY - sy;
            // 限制在视口内
            const ww = win.offsetWidth, wh = win.offsetHeight;
            const vw = window.innerWidth, vh = window.innerHeight;
            const cx = Math.max(0, Math.min(nx, vw - 40));
            const cy = Math.max(0, Math.min(ny, vh - 30));
            win.style.left = cx + 'px';
            win.style.top = cy + 'px';
            win.style.right = 'auto';
            win.style.bottom = 'auto';
        });
        document.addEventListener('mouseup', () => { if (on) { on = false; saveWinPos(); } });
    })();

    // 浮动按钮拖拽 & 位置保存
    async function saveFabPos() {
        try {
            const r = fab.getBoundingClientRect();
            await cloudStorage.setItem('xl_fab_pos', JSON.stringify({ left: r.left, top: r.top }));
        } catch (e) { /* ignore */ }
    }
    // 初始位置
    async function restoreFabPos() {
        try {
            const raw = await cloudStorage.getItem('xl_fab_pos');
            if (raw) {
                const pos = JSON.parse(raw);
                fab.style.left = pos.left + 'px';
                fab.style.top = pos.top + 'px';
                fab.style.right = 'auto';
                fab.style.bottom = 'auto';
            }
        } catch (e) { /* ignore */ }
    }
    (function () {
        let on = false, moved = false, sx, sy, ox, oy;
        fab.addEventListener('mousedown', e => {
            on = true; moved = false;
            sx = e.clientX; sy = e.clientY;
            const r = fab.getBoundingClientRect();
            ox = r.left; oy = r.top;
            e.preventDefault();
        });
        document.addEventListener('mousemove', e => {
            if (!on) return;
            const dx = e.clientX - sx, dy = e.clientY - sy;
            if (!moved && Math.abs(dx) < 4 && Math.abs(dy) < 4) return;
            moved = true;
            const nx = ox + dx, ny = oy + dy;
            const vw = window.innerWidth, vh = window.innerHeight;
            const fw = fab.offsetWidth, fh = fab.offsetHeight;
            const cx = Math.max(0, Math.min(nx, vw - fw));
            const cy = Math.max(0, Math.min(ny, vh - fh));
            fab.style.left = cx + 'px';
            fab.style.top = cy + 'px';
            fab.style.right = 'auto';
            fab.style.bottom = 'auto';
        });
        document.addEventListener('mouseup', () => {
            if (on && moved) { fab.dataset.dragged = '1'; saveFabPos(); }
            on = false;
        });
    })();
    restoreFabPos();

    /*================文章区==================*/
    articleTab.addEventListener('click', async () => {
        chatroomTab.removeAttribute('class');
        chatroomTab.setAttribute('class', 'xl-tab');
        columnTab.removeAttribute('class');
        columnTab.setAttribute('class', 'xl-tab');
        articleTab.setAttribute('class', 'xl-tab xl-tab-file');
        isArticleMode = true;

        stopChatroom();
        let list = [];
        try {
            const data = await v3Fetch('/articles?p=1&size=50&sort=latest&type=recent');
            const articles = (data && data.list) || [];
            articles.reverse().forEach(article => {
                const isStick = article.stick && article.stick.active;
                const title = article.title || '无标题';
                const author = article.author || {};
                const sender = author.userNickname ? author.userNickname + '(' + author.userName + ')' : (author.userName || '匿名');
                const contentHtml = `<a href='#' style='color:#217346;cursor:pointer'>${isStick ? '【置顶】' : ''}${esc(title)}</a>`;
                list.push({
                    time: formatDateTime(article.updatedAt || article.createdAt),
                    content: isStick ? '【置顶】' + title : title,
                    contentHtml: contentHtml,
                    sender: sender,
                    oId: article.id
                });
            });
            messages = list;
            renderAll();
        } catch (err) {
            console.error(err);
        }

    });

    chatroomTab.addEventListener('click', async () => {
        messages = []
        isArticleMode = false;
        removeArticleDetail();
        articleTab.removeAttribute('class');
        articleTab.setAttribute('class', 'xl-tab');
        columnTab.removeAttribute('class');
        columnTab.setAttribute('class', 'xl-tab');
        getHistoryMessages();
        startLisentChatroom();
        chatroomTab.setAttribute('class', 'xl-tab xl-tab-file');
    });

    columnTab.addEventListener('click', async () => {
        articleTab.removeAttribute('class');
        articleTab.setAttribute('class', 'xl-tab');
        chatroomTab.removeAttribute('class');
        chatroomTab.setAttribute('class', 'xl-tab');
        columnTab.setAttribute('class', 'xl-tab xl-tab-file');
        loadLongArticleList();
    });

    /* ══════════ 文章详情展示（WPS Word模板） ══════════ */
    let articleDetailEl = null;

    function removeArticleDetail() {
        if (articleDetailEl) { articleDetailEl.remove(); articleDetailEl = null; }
        // 恢复Excel窗口
        win.classList.add('_xl_open');
        fab.classList.add('_xl_hide');
        isPanelOpen = true;
    }

    function showArticleDetail(oId) {
        removeArticleDetail();
        // 隐藏Excel窗口
        win.classList.remove('_xl_open');
        fab.classList.remove('_xl_hide');
        isPanelOpen = false;

        const wrap = document.createElement('div');
        wrap.className = 'xl-wrd-wrap';
        wrap.innerHTML = `
      <!-- 顶部WPS菜单栏 -->
      <div class="xl-wrd-topbar">
        <div class="xl-wrd-topbar-left">
          <img src="https://file.fishpi.cn/2026/08/804-9faa02a5.png" class="xl-wrd-logo" />
        </div>

        <div class="xl-wrd-toolbar">
          <div class="xl-wrd-btn-close" id="_xl_wrd_thank">感谢</div>
          <div class="xl-wrd-btn-close" id="_xl_wrd_good">点赞</div>
          <div class="xl-wrd-btn-close" id="_xl_wrd_close">关闭返回</div>
        </div>
      </div>
      <!-- 主体 -->
      <div class="xl-wrd-main">
        <div class="xl-wrd-doc" id="_xl_wrd_doc">
          <div class="xl-wrd-page" id="_xl_wrd_page">
            <div class="xl-wrd-loading">正在加载文章内容…</div>
          </div>
        </div>
        <div class="xl-wrd-sidebar" id="_xl_wrd_sidebar">
          <div class="xl-wrd-sidebar-empty">暂无评论</div>
        </div>
      </div>
      <!-- 底部状态栏 -->
      <div class="xl-wrd-statusbar" id="_xl_wrd_status">
        <span>页面: 1/1</span>
        <span id="_xl_wrd_wordcnt">字数: 0</span>
      </div>
    `;
      document.body.appendChild(wrap);
      articleDetailEl = wrap;

      // 关闭返回按钮
      wrap.querySelector('#_xl_wrd_close').addEventListener('click', () => {
          removeArticleDetail();
      });

      // ── 感谢文章 ──
      const thankBtn = wrap.querySelector('#_xl_wrd_thank');
      thankBtn.addEventListener('click', (e) => {
          e.stopPropagation();
          removeWrdThankBubble();
          const bubble = document.createElement('div');
          bubble.className = 'xl-wrd-thank-bubble';
          bubble.innerHTML = `
        <div class="xl-tb-tip">💡 感谢将消耗 20 积分，确定感谢吗？</div>
        <div class="xl-tb-btns">
          <button class="xl-tb-btn xl-tb-cancel">取消</button>
          <button class="xl-tb-btn xl-tb-ok">确定感谢</button>
        </div>
      `;
        thankBtn.style.position = 'relative';
        thankBtn.appendChild(bubble);
        bubble.querySelector('.xl-tb-cancel').addEventListener('click', (ev) => { ev.stopPropagation(); removeWrdThankBubble(); });
        bubble.querySelector('.xl-tb-ok').addEventListener('click', async (ev) => {
            ev.stopPropagation();
            removeWrdThankBubble();
            try {
                await v3Fetch('/articles/' + oId + '/thanks', {
                    method: 'POST',
                    headers: { 'Idempotency-Key': genIdempotencyKey('article-thank') },
                    body: '{}'
                });
                thankBtn.textContent = '已感谢';
                thankBtn.style.pointerEvents = 'none';
                thankBtn.classList.toggle('xl-wrd-like-active');
            } catch (err) {
                alert('感谢失败: ' + (err.message || err));
            }
        });
    });

      // ── 点赞/取消点赞 ──
      const goodBtn = wrap.querySelector('#_xl_wrd_good');
      goodBtn.addEventListener('click', async (e) => {
          e.stopPropagation();
          const isLiked = goodBtn.dataset.liked === '1';
          try {
              if (isLiked) {
                  await v3Fetch('/articles/' + oId + '/vote', {
                      method: 'DELETE',
                      headers: { 'Idempotency-Key': genIdempotencyKey('article-vote') },
                      body: '{}'
                  });
              } else {
                  await v3Fetch('/articles/' + oId + '/vote', {
                      method: 'PUT',
                      headers: { 'Idempotency-Key': genIdempotencyKey('article-vote') },
                      body: JSON.stringify({ vote: 'up' })
                  });
              }
              const newLiked = !isLiked;
              goodBtn.dataset.liked = newLiked ? '1' : '0';
              goodBtn.textContent = newLiked ? '取消点赞' : '点赞';
              goodBtn.classList.toggle('xl-wrd-like-active', newLiked);
          } catch (err) {
              alert((isLiked ? '取消点赞' : '点赞') + '失败: ' + (err.message || err));
          }
      });

      // 加载文章详情
      loadArticleDetail(oId);
  }

    // 加载文章详情
    async function loadArticleDetail(oId) {
        const pageEl = document.getElementById('_xl_wrd_page');
        const sidebarEl = document.getElementById('_xl_wrd_sidebar');
        try {
            const article = await v3Fetch('/articles/' + oId + '?includeInteractions=true');
            const commentsData = await v3Fetch('/articles/' + oId + '/comments?p=1&size=50&sort=oldest');
            const comments = (commentsData && commentsData.list) || [];
            if (!article) {
                pageEl.innerHTML = '<div class="xl-wrd-error">文章不存在或已被删除</div>';
                return;
            }
            // 作者与时间
            const author = article.author || {};
            const authorName = author.userNickname || author.userName || '未知作者';
            const createTime = formatDateTime(article.createdAt);
            const title = article.title || '';
            // 文章内容（HTML格式直接解析）
            const contentHtml = article.contentHtml || article.content || '';
            // 渲染文章页面
            let pageHtml = '';
            if (title) {
                pageHtml += '<h2 style="text-indent:0;text-align:center;margin-bottom:20px;">' + esc(title) + '</h2>';
            }
            pageHtml += '<div class="xl-wrd-meta">';
            pageHtml += '作者:<span class="xl-wrd-author">' + esc(authorName) + '</span>';
            if (createTime) pageHtml += '<span> ' + esc(createTime) + '</span>';
            pageHtml += '</div>';
            if (contentHtml) {
                pageHtml += contentHtml;
            } else {
                pageHtml += '<p style="text-indent:0;color:#999;">文章内容为空</p>';
            }
            pageEl.innerHTML = pageHtml;
            // 字数统计
            const textLen = pageEl.textContent ? pageEl.textContent.replace(/\s+/g, '').length : 0;
            const wordCntEl = document.getElementById('_xl_wrd_wordcnt');
            if (wordCntEl) wordCntEl.textContent = '字数: ' + textLen;

            // ── 打赏区 ──
            const rewardContent = article.rewardContentHtml || article.rewardContent || '';
            const rewardPoint = article.rewardPoint || 0;
            const isRewarded = !!article.rewarded;
            const hasReward = rewardPoint >= 1;
            if (hasReward) {
                const rewardDiv = document.createElement('div');
                rewardDiv.className = 'xl-wrd-reward';
                if (isRewarded) {
                    rewardDiv.innerHTML =
                        '<div class="xl-wrd-reward-title">🎁 打赏区</div>' +
                        '<div class="xl-wrd-reward-info">打赏金额: <b>' + esc(String(rewardPoint)) + '</b> 积分</div>' +
                        '<div class="xl-wrd-reward-status">✅ 您已打赏过，以下是打赏内容</div>' +
                        '<div class="xl-wrd-reward-content">' + rewardContent + '</div>';
                } else {
                    rewardDiv.innerHTML =
                        '<div class="xl-wrd-reward-title">🎁 打赏区</div>' +
                        '<div class="xl-wrd-reward-info">打赏金额: <b>' + esc(String(rewardPoint)) + '</b> 积分</div>' +
                        '<button class="xl-wrd-reward-btn" id="_xl_wrd_reward_btn">打赏 ' + esc(String(rewardPoint)) + ' 积分查看内容</button>';
                }
                pageEl.appendChild(rewardDiv);
                if (!isRewarded) {
                    const rewardBtn = pageEl.querySelector('#_xl_wrd_reward_btn');
                    if (rewardBtn) {
                        rewardBtn.addEventListener('click', async () => {
                            if (!confirm('确定打赏 ' + rewardPoint + ' 积分查看隐藏内容吗？')) return;
                            rewardBtn.disabled = true;
                            rewardBtn.textContent = '打赏中…';
                            try {
                                await v3Fetch('/articles/' + oId + '/reward', {
                                    method: 'POST',
                                    headers: { 'Idempotency-Key': genIdempotencyKey('article-reward') },
                                    body: '{}'
                                });
                                loadArticleDetail(oId);
                            } catch (err) {
                                alert('打赏失败: ' + (err.message || err));
                                rewardBtn.disabled = false;
                                rewardBtn.textContent = '打赏 ' + rewardPoint + ' 积分查看内容';
                            }
                        });
                    }
                }
            }

            // 渲染评论
            renderWrdComments(sidebarEl, comments);
            // 渲染评论输入区
            renderCommentInput(sidebarEl, oId);

            // ── 设置感谢/点赞初始状态 ──
            if (articleDetailEl) {
                const interactions = article.interactions || {};
                const thanks = interactions.thanks || {};
                const voteState = interactions.vote || {};
                // 感谢状态
                if (thanks.thanked) {
                    const thankBtn = articleDetailEl.querySelector('#_xl_wrd_thank');
                    if (thankBtn) {
                        thankBtn.textContent = '已感谢';
                        thankBtn.style.pointerEvents = 'none';
                        thankBtn.classList.add('xl-wrd-like-active');
                    }
                }
                // 点赞状态：vote 为 up/down 表示已投票
                if (voteState.vote === 'up' || voteState.vote === 'down') {
                    const goodBtn = articleDetailEl.querySelector('#_xl_wrd_good');
                    if (goodBtn) {
                        goodBtn.textContent = '取消点赞';
                        goodBtn.classList.add('xl-wrd-like-active');
                        goodBtn.dataset.liked = '1';
                    }
                }
            }
        } catch (err) {
            console.error('加载文章详情失败:', err);
            pageEl.innerHTML = '<div class="xl-wrd-error">加载失败: ' + esc(err.message || String(err)) + '</div>';
        }
    }

    async function loadLongArticleList() {
        isArticleMode = true;
        stopChatroom();
        messages = [];
        try {
            const data = await v3Fetch('/articles?p=1&size=50&sort=latest&type=long');
            const list = (data && data.list) || [];
            console.log('长文章列表:', list);
            list.forEach(article => {
                const articleTitle = article.title || '无标题';
                const author = article.author || {};
                const sender = author.userNickname || author.userName || '匿名';
                const updateTime = article.updatedAt || article.createdAt || '';
                const oId = article.id;
                const content = articleTitle;
                const contentHtml = '<a href="#" style="color:#217346;cursor:pointer">' + esc(articleTitle) + '</a>'
                + ' <span style="color:#999;">·</span> '
                + '<span style="color:#666;">' + esc(sender) + '</span>';
                messages.push({
                    time: formatDateTime(updateTime),
                    content: content,
                    contentHtml: contentHtml,
                    sender: sender,
                    oId: oId
                });
            });
            renderAll();
        } catch (err) {
            console.error('加载长文章列表失败:', err);
            statEl.textContent = '加载长文章列表失败';
        }
    }

    async function loadLongArticleDetail(oId) {

    }


    function renderWrdComments(sidebarEl, rawComments) {
        if (!rawComments || rawComments.length === 0) {
            sidebarEl.innerHTML = '<div class="xl-wrd-sidebar-empty">暂无评论</div>';
            return;
        }
        // 0. v3 评论 → 旧内部结构
        const mapped = rawComments.map(c => ({
            oId: c.id,
            originalId: c.parentId || '',
            commentAuthorName: (c.author && (c.author.userNickname || c.author.userName)) || '匿名',
            commentContent: c.contentHtml || c.content || '暂无内容',
            commentCreateTime: formatDateTime(c.createdAt)
        }));
        // 1. 颠倒顺序
        const comments = [...mapped].reverse();
        // 2. 建立 oId 索引
        const idMap = {};
        comments.forEach(c => { if (c.oId) idMap[c.oId] = c; });
        // 3. 构建嵌套树：originalId 非空且匹配某评论的 oId，则归为该评论的子回复
        const roots = [];
        comments.forEach(c => {
            c._children = [];
        });
        comments.forEach(c => {
            const pid = c.originalId || '';
            if (pid && idMap[pid]) {
                idMap[pid]._children.push(c);
            } else {
                roots.push(c);
            }
        });
        // 4. 递归渲染
        function renderNode(item, depth) {
            const author = item.commentAuthorName || item.authorName || '匿名';
            const content = item.commentContent || item.content || '暂无内容';
            const cmtId = item.oId || '';
            const orId = item.originalId || '';
            const div = document.createElement('div');
            if (depth === 0) {
                div.className = 'xl-wrd-comment-card';
            } else {
                div.className = 'xl-wrd-comment-reply';
            }
            const cmtTime = item.commentCreateTime || item.createTime || '';
            let html = '<div class="xl-wrd-comment-author">' + esc(author);
            if (cmtTime) html += '<span class="xl-wrd-comment-time">' + esc(cmtTime) + '</span>';
            html += '</div>';
            html += '<div class="xl-wrd-comment-text">' + content + '</div>';
            html += '<div style="margin-top:4px"><span class="xl-wrd-cmt-reply-btn" data-cmt-id="' + esc(cmtId) + ' " data-or-id="' + esc(orId) + '" " data-cmt-author="' + esc(author) + '" style="font-size:11px;color:#217346;cursor:pointer">回复</span></div>';
            div.innerHTML = html;
            // 回复按钮事件
            const replyBtn = div.querySelector('.xl-wrd-cmt-reply-btn');
            if (replyBtn) {
                replyBtn.addEventListener('click', (e) => {
                    e.stopPropagation();
                    if (typeof window._wrdSetReply === 'function') {
                        window._wrdSetReply(replyBtn.dataset.orId, replyBtn.dataset.cmtId, replyBtn.dataset.cmtAuthor);
                    }
                });
            }
            // 递归渲染子回复
            if (item._children && item._children.length > 0) {
                item._children.forEach(child => {
                    div.appendChild(renderNode(child, depth + 1));
                });
            }
            return div;
        }
        sidebarEl.innerHTML = '';
        roots.forEach(item => {
            sidebarEl.appendChild(renderNode(item, 0));
        });
    }

    function removeWrdThankBubble() {
        if (!articleDetailEl) return;
        articleDetailEl.querySelectorAll('.xl-wrd-thank-bubble').forEach(b => b.remove());
    }

    // 关闭感谢气泡（点击外部）
    document.addEventListener('click', (e) => {
        if (!articleDetailEl) return;
        const bubble = articleDetailEl.querySelector('.xl-wrd-thank-bubble');
        if (bubble && !bubble.contains(e.target)) removeWrdThankBubble();
    });

    // ── 评论输入区渲染 ──
    function renderCommentInput(sidebarEl, oId) {
        const wrap = document.createElement('div');
        wrap.className = 'xl-wrd-cmt-wrap';
        wrap.id = '_xl_wrd_cmt_wrap';
        wrap.innerHTML = `
      <div class="xl-wrd-reply-tag" id="_xl_wrd_reply_tag" style="display:none">
        <span id="_xl_wrd_reply_tag_text"></span>
        <span class="xl-rt-close" id="_xl_wrd_reply_cancel">✕</span>
      </div>
      <div class="xl-wrd-cmt-toolbar" style="position:relative">
        <button id="_xl_wrd_cmt_emoji" title="默认表情">😀</button>
        <button id="_xl_wrd_cmt_legacy" title="收藏表情">⭐</button>
        <button id="_xl_wrd_cmt_img" title="上传图片">🖼</button>
        <input type="file" accept="image/*" id="_xl_wrd_cmt_file" style="display:none" />
      </div>
      <textarea class="xl-wrd-cmt-textarea" id="_xl_wrd_cmt_ta" placeholder="写评论…"></textarea>
      <div class="xl-wrd-cmt-actions">
        <span id="_xl_wrd_cmt_status" style="font-size:11px;color:#999"></span>
        <button class="xl-wrd-cmt-submit" id="_xl_wrd_cmt_submit">发布评论</button>
      </div>
    `;
      sidebarEl.appendChild(wrap);

      const textarea = wrap.querySelector('#_xl_wrd_cmt_ta');
      const submitBtn = wrap.querySelector('#_xl_wrd_cmt_submit');
      const statusSpan = wrap.querySelector('#_xl_wrd_cmt_status');
      const replyTag = wrap.querySelector('#_xl_wrd_reply_tag');
      const replyTagText = wrap.querySelector('#_xl_wrd_reply_tag_text');
      const replyCancel = wrap.querySelector('#_xl_wrd_reply_cancel');
      const emojiBtn = wrap.querySelector('#_xl_wrd_cmt_emoji');
      const legacyBtn = wrap.querySelector('#_xl_wrd_cmt_legacy');
      const imgBtn = wrap.querySelector('#_xl_wrd_cmt_img');
      const fileInput = wrap.querySelector('#_xl_wrd_cmt_file');

      let replyCommentId = null; // 回复的评论ID
      let cmtEmojiPanel = null;

      // 设置回复目标
      window._wrdSetReply = function (orCommentId, commentId, authorName) {
          replyCommentId = commentId.trim();
          replyTag.style.display = 'flex';
          replyTagText.textContent = '回复 @' + authorName;
          textarea.placeholder = '回复 @' + authorName + '…';
          textarea.focus();
      };

      // 取消回复
      replyCancel.addEventListener('click', () => {
          replyCommentId = null;
          replyTag.style.display = 'none';
          textarea.placeholder = '写评论…';
      });

      // emoji面板
      function removeCmtEmojiPanel() {
          if (cmtEmojiPanel) { cmtEmojiPanel.remove(); cmtEmojiPanel = null; }
      }

      function showCmtEmojiPanel(mode) {
          removeCmtEmojiPanel();
          const panel = document.createElement('div');
          panel.className = 'xl-wrd-cmt-emoji-panel';
          // tabs
          const tabs = document.createElement('div');
          tabs.className = 'xl-wrd-cmt-emoji-tabs';
          const tabD = document.createElement('button');
          tabD.className = 'xl-wrd-cmt-emoji-tab' + (mode === 'default' ? ' wce-active' : '');
          tabD.textContent = '默认';
          tabD.addEventListener('click', (ev) => { ev.stopPropagation(); showCmtEmojiPanel('default'); });
          const tabL = document.createElement('button');
          tabL.className = 'xl-wrd-cmt-emoji-tab' + (mode === 'legacy' ? ' wce-active' : '');
          tabL.textContent = '收藏';
          tabL.addEventListener('click', (ev) => { ev.stopPropagation(); showCmtEmojiPanel('legacy'); });
          tabs.appendChild(tabD);
          tabs.appendChild(tabL);
          panel.appendChild(tabs);
          // body
          const body = document.createElement('div');
          body.className = 'xl-wrd-cmt-emoji-body';
          if (mode === 'default') {
              const keys = Object.keys(defaultEmojis);
              if (keys.length === 0) {
                  body.innerHTML = '<div style="padding:20px;text-align:center;color:#aaa;font-size:11px">暂无表情</div>';
              } else {
                  keys.forEach(name => {
                      const item = document.createElement('div');
                      item.className = 'xl-wrd-cmt-emoji-item';
                      item.title = name;
                      item.style.width = 'auto';
                      item.style.height = 'auto';
                      item.style.padding = '4px 6px';
                      item.style.fontSize = '16px';
                      item.style.whiteSpace = 'nowrap';
                      item.textContent = defaultEmojis[name] || (':' + name + ':');
                      item.addEventListener('click', () => {
                          insertCmtEmoji(':' + name + ':');
                          removeCmtEmojiPanel();
                      });
                      body.appendChild(item);
                  });
              }
          } else {
              // 收藏表情模式：分组子标签 + 表情列表（与聊天室一致）
              if (emojiGroups && emojiGroups.length > 0) {
                  const groupTabs = document.createElement('div');
                  groupTabs.className = 'xl-emoji-group-tabs';
                  let cmtGroupIndex = currentGroupIndex;
                  emojiGroups.forEach((group, idx) => {
                      const gTab = document.createElement('button');
                      gTab.className = 'xl-emoji-group-tab' + (idx === cmtGroupIndex ? ' xl-emoji-group-tab-active' : '');
                      gTab.textContent = group.name;
                      gTab.addEventListener('click', async (ev) => {
                          ev.stopPropagation();
                          cmtGroupIndex = idx;
                          if (group.oId === 'all') {
                              groupEmojiList = [];
                          } else {
                              await loadGroupEmojis(group.oId);
                          }
                          // 更新激活样式
                          groupTabs.querySelectorAll('.xl-emoji-group-tab').forEach((t, i) => {
                              t.className = 'xl-emoji-group-tab' + (i === idx ? ' xl-emoji-group-tab-active' : '');
                          });
                          // 重新渲染body
                          renderCmtEmojiBody(body, group);
                      });
                      groupTabs.appendChild(gTab);
                  });
                  panel.appendChild(body);
                  panel.insertBefore(groupTabs, body);
              }
              // 渲染当前分组的表情
              const curGroup = (emojiGroups && emojiGroups.length > 0) ? emojiGroups[currentGroupIndex] : null;
              renderCmtEmojiBody(body, curGroup);
          }
          if (!panel.contains(body)) panel.appendChild(body);
          wrap.querySelector('.xl-wrd-cmt-toolbar').appendChild(panel);
          cmtEmojiPanel = panel;
      }

      // 渲染收藏表情body（与聊天室结构一致）
      function renderCmtEmojiBody(body, group) {
          body.innerHTML = '';
          const currentEmojis = (group && group.oId !== 'all') ? groupEmojiList : legacyEmojis;
          if (!currentEmojis || currentEmojis.length === 0) {
              body.innerHTML = '<div style="padding:20px;text-align:center;color:#aaa;font-size:11px">暂无收藏表情</div>';
              return;
          }
          currentEmojis.forEach(em => {
              const item = document.createElement('div');
              item.className = 'xl-wrd-cmt-emoji-item';
              item.innerHTML = '<img src="' + (em.url || em) + '" />';
              item.addEventListener('click', () => {
                  insertCmtEmoji('![' + (em.name || '图片') + '](' + (em.url || em) + ')');
                  removeCmtEmojiPanel();
              });
              body.appendChild(item);
          });
      }

      function insertCmtEmoji(tag) {
          const start = textarea.selectionStart;
          const end = textarea.selectionEnd;
          const val = textarea.value;
          textarea.value = val.slice(0, start) + tag + val.slice(end);
          textarea.selectionStart = textarea.selectionEnd = start + tag.length;
          textarea.focus();
      }

      emojiBtn.addEventListener('click', (e) => {
          e.stopPropagation();
          if (cmtEmojiPanel) { removeCmtEmojiPanel(); return; }
          showCmtEmojiPanel('default');
      });
      legacyBtn.addEventListener('click', (e) => {
          e.stopPropagation();
          if (cmtEmojiPanel) { removeCmtEmojiPanel(); return; }
          showCmtEmojiPanel('legacy');
      });

      // 点击外部关闭emoji面板
      document.addEventListener('click', (e) => {
          if (cmtEmojiPanel && !cmtEmojiPanel.contains(e.target) && e.target !== emojiBtn && e.target !== legacyBtn) {
              removeCmtEmojiPanel();
          }
      });

      // 图片上传
      imgBtn.addEventListener('click', (e) => {
          e.stopPropagation();
          fileInput.value = '';
          fileInput.click();
      });

      fileInput.addEventListener('change', async (e) => {
          const files = e.target.files;
          if (!files || files.length === 0) return;
          const file = files[0];
          if (!file.type.startsWith('image/')) { statusSpan.textContent = '请选择图片文件'; return; }
          if (file.size > 20 * 1024 * 1024) { statusSpan.textContent = '图片不能超过20MB'; return; }
          try {
              statusSpan.textContent = '上传中…';
              const urls = await uploadV3Images(files);
              const url = urls && urls[0];
              if (url) {
                  insertCmtEmoji('![图片](' + url + ')');
                  statusSpan.textContent = '上传成功';
              } else {
                  statusSpan.textContent = '上传返回异常';
              }
              setTimeout(() => { statusSpan.textContent = ''; }, 3000);
          } catch (err) {
              statusSpan.textContent = '上传失败: ' + err.message;
          }
      });
      // 从番茄锅底中心舀出适量汤汁（避开浮油），在碗中加入牛肉粒、香菜或葱花，再倒入热米饭拌匀，静置30秒让米饭吸饱汤汁，酸甜开胃又满足

      // 提交评论
      submitBtn.addEventListener('click', async () => {
          const content = textarea.value.trim();
          if (!content) { statusSpan.textContent = '请输入评论内容'; return; }
          submitBtn.disabled = true;
          statusSpan.textContent = '发布中…';
          try {
              const payload = { content: content, anonymous: false, visible: false };
              if (replyCommentId) payload.parentId = replyCommentId;
              await v3Fetch('/articles/' + oId + '/comments', {
                  method: 'POST',
                  headers: { 'Idempotency-Key': genIdempotencyKey('cmt-post') },
                  body: JSON.stringify(payload)
              });
              textarea.value = '';
              replyCommentId = null;
              replyTag.style.display = 'none';
              textarea.placeholder = '写评论…';
              statusSpan.textContent = '评论成功！';
              // 刷新评论列表
              loadArticleDetail(oId);
              setTimeout(() => { statusSpan.textContent = ''; }, 3000);
          } catch (err) {
              statusSpan.textContent = '评论失败: ' + err.message;
          }
          submitBtn.disabled = false;
      });
  }

    // 网格行点击：文章模式下打开文章详情
    gridEl.addEventListener('click', (e) => {
        if (!isArticleMode) return;
        const row = e.target.closest('.xl-row');
        if (!row) return;
        const idx = parseInt(row.dataset.idx, 10);
        const msg = messages[idx];
        if (msg && msg.oId) {
            showArticleDetail(msg.oId);
        }
    });


    /* ══════════ 初始化 ══════════ */
    let initialized = false;
    async function init() {
        if (initialized) return;
        initialized = true;
        try {
            getHistoryMessages();
            await startLisentChatroom();
            startLisentNotice();
            startLisentPreMgs();
            loadNoticeUnreadCount();
            loadUnreadPreMgsList();
            loadAccountInfo();
            loaddefaultEmoji();
            loadEmojiGroups();
            loadShortcutsConfig();
            await loadAllPreMgsList();
            buildChatUnreadList();
        } catch (err) {
            console.error("初始化失败:", err);
        }
    }

    window.addEventListener('beforeunload', () => {
        stopChatroom();
        if (noticeChannel) noticeChannel.stop();
        if (premsgChannel) premsgChannel.stop();
    });

    // 启动入口
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init);
    } else {
        init();
    }
})();

```