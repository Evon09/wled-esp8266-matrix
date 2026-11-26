// Testes headless dos jogos: sintaxe do script inteiro, partidas aleatórias, fases e jogadas automáticas.
const fs = require('fs'), vm = require('vm');
const html = fs.readFileSync(require('path').join(__dirname, '..', 'jogos.src.htm'), 'utf8');
const scripts = [...html.matchAll(/<script>([\s\S]*?)<\/script>/g)].map(m => m[1]);
for (const s of scripts) new vm.Script(s);
console.log('sintaxe OK em', scripts.length, 'blocos');
const logic = html.split('/*GAMES-START*/')[1].split('/*GAMES-END*/')[0];
const ctx = { Math, Uint32Array, Uint8Array, Array, Set, String, Object, console };
vm.createContext(ctx);
vm.runInContext(logic + ';this.GAMES=GAMES;this.F=F;this.LEVELS=LEVELS;this.Platform=Platform;this.FONT=FONT', ctx);
const { GAMES, F } = ctx;
const API = { sfx() {} };
const KEYS = ['up', 'down', 'left', 'right', 'a', 'b'];
function input() {
  const held = [new Set(), new Set()], hit = [new Set(), new Set()], ptr = [null, null], tap = [null, null];
  return { held, hitS: hit, ptr, tapS: tap, I: { held: (p, k) => held[p].has(k) || hit[p].has(k), hit: (p, k) => hit[p].has(k), pointer: p => ptr[p], tap: p => tap[p] } };
}
let fail = 0;
const check = (name, ok, extra) => { console.log((ok ? 'ok   ' : 'FALHA') + ' ' + name + (extra ? '  ' + extra : '')); if (!ok) fail++; };

// 1) partidas com entradas aleatórias, todas as variações de opções
for (const d of GAMES) {
  const variants = [];
  for (const players of d.players || [1]) for (const level of [0, 2]) for (const layout of ['lr', 'tb']) for (const walls of ['wrap', 'wall']) variants.push({ players, level, layout, walls });
  let overs = 0, runs = 0, bad = null;
  for (const o of variants) for (let r = 0; r < 4; r++) {
    const g = d.make(Object.assign({}, o), API), x = input(); runs++;
    try {
      for (let t = 0; t < 60 * 240 && !g.over; t++) {
        x.hitS[0].clear(); x.hitS[1].clear(); x.tapS[0] = null;
        for (let p = 0; p < 2; p++) if (Math.random() < .08) { const k = KEYS[Math.random() * 6 | 0]; if (x.held[p].has(k)) x.held[p].delete(k); else { x.held[p].add(k); x.hitS[p].add(k); } }
        if (d.drag && Math.random() < .02) x.ptr[0] = Math.random() < .5 ? null : { x: Math.random() * 16, y: Math.random() * 16 };
        if (d.id === 'genius' && Math.random() < .02) x.tapS[0] = { x: Math.random() * 16, y: Math.random() * 16 };
        g.update(1 / 60, x.I);
        if (t % 7 === 0) { g.draw(); g.hud(); for (const v of F.px) if (!(v >= 0 && v <= 0xffffff)) throw new Error('cor inválida ' + v); }
      }
      g.draw(); g.hud(); if (g.over) overs++; if (!Number.isFinite(g.score)) throw new Error('pontos inválidos');
    } catch (e) { bad = e.stack.split('\n').slice(0, 3).join(' | '); }
  }
  check(`${d.id}: ${runs} partidas aleatórias sem erro (${overs} terminaram)`, !bad, bad || '');
}

// 2) plataforma: cada fase tem de ter um caminho até a bandeira (busca com a física real do jogo)
const ACTS = [['right'], ['right', 'a'], [], ['a'], ['left'], ['left', 'a']], STEP = 8;
function replay(level, path) {
  const g = ctx.Platform({ start: level }, API), x = input();
  x.held[0].add('a'); g.update(1 / 60, x.I); x.held[0].clear(); // fecha o letreiro da fase
  x.hitS[0].add('a'); g.update(1 / 60, x.I); x.hitS[0].clear();
  for (let i = 0; i < 80; i++) g.update(1 / 60, x.I);
  let prevJ = false, ticks = 0;
  for (const a of path) {
    const act = ACTS[a];
    for (let t = 0; t < STEP; t++) {
      x.held[0] = new Set(act); x.held.length = 2; x.hitS[0].clear(); if (act.includes('a') && !prevJ) x.hitS[0].add('a'); prevJ = act.includes('a');
      x.I.held = (p, k) => p === 0 && (act.includes(k) || x.hitS[0].has(k));
      g.update(1 / 60, x.I); ticks++;
      const s = g.state(); if (s.li !== level || g.winner) return { won: true, ticks }; if (s.lives < 3 || g.over) return { dead: true };
    }
  }
  return { s: g.state(), ticks };
}
for (let level = 0; level < ctx.LEVELS.length; level++) {
  const seen = new Set(), open = [{ path: [], pr: 0 }]; let n = 0, won = null, far = 0;
  while (open.length && n < 40000 && !won) {
    let bi = 0; for (let i = 1; i < open.length; i++) if (open[i].pr > open[bi].pr) bi = i;
    const node = open.splice(bi, 1)[0];
    for (let a = 0; a < ACTS.length; a++) {
      const path = node.path.concat(a), r = replay(level, path); n++;
      if (r.won) { won = { secs: r.ticks / 60, steps: path.length }; break; }
      if (r.dead) continue;
      const s = r.s, key = [Math.round(s.x * 3), Math.round(s.y * 3), Math.round(s.vy / 4), s.ground, a & 1, Math.floor(r.ticks / 60)].join(',');
      if (seen.has(key)) continue; seen.add(key); far = Math.max(far, s.x);
      open.push({ path, pr: s.x - path.length * .02 });
    }
  }
  check(`plataforma: fase ${level + 1} dá para terminar`, !!won, won ? `(${won.secs.toFixed(1)} s de jogo, ${n} tentativas)` : `parou em x=${far.toFixed(1)} de ${ctx.LEVELS[level].flag}`);
}

// 3) jogadas automáticas simples: dá para pontuar e as regras fecham
function auto(id, o, brain, secs) { const d = GAMES.find(z => z.id === id), g = d.make(o, API), x = input(); for (let t = 0; t < 60 * secs && !g.over; t++) { x.hitS[0].clear(); x.hitS[1].clear(); x.tapS[0] = null; brain(g, x, t); g.update(1 / 60, x.I); } g.draw(); return g; }
let g = auto('tijolos', { players: 1 }, (g, x, t) => { x.hitS[0].add('a'); g.draw(); let bx = -1; for (let y = 14; y >= 0 && bx < 0; y--) for (let i = 0; i < 16; i++) if (F.px[y * 16 + i] === 0xffffff) { bx = i; break; } if (bx >= 0) x.ptr[0] = { x: bx + .5 + Math.sin(t / 37) * 1.4, y: 15 }; }, 600);
check('tijolos: raquete automática limpa blocos e passa de fase', g.score >= 500, g.hud());
g = auto('genius', {}, (g, x) => { if (g.phase() === 'input') { g._i = g._i || 0; if (!g._w || --g._w <= 0) { const n = ['up', 'right', 'down', 'left'][g.seq[g._i]]; x.hitS[0].add(n); g._i++; g._w = 25; if (g._i >= g.seq.length) g._i = 0; } } else if (g.phase() === 'show') { g._i = 0; g._w = 25; } }, 120);
check('genius: repetir certo aumenta a sequência', g.score >= 6, g.hud());
g = auto('genius', {}, (g, x) => { if (g.phase() === 'input') x.hitS[0].add(['up', 'right', 'down', 'left'][(g.seq[0] + 1) % 4]); }, 30);
check('genius: errar encerra', g.over && g.score === 0);
g = auto('pong', { players: 2, level: 1, layout: 'lr' }, () => {}, 300);
check('pong 2 jogadores: partida vai até 7 e tem vencedor', g.over && Math.max(...g.pts) === 7 && !!g.winner, g.hud() + ' ' + g.winner);
g = auto('tron', { players: 2 }, () => {}, 60);
check('tron: batida dupla sem ninguém mexer não trava', !g.over && g.wins[0] === 0);
g = auto('tron', { players: 1, level: 2 }, () => {}, 120);
check('tron: a placa vence quem não joga', g.over && g.wins[1] === 3, g.hud());
g = auto('snake', { players: 2, walls: 'wrap' }, (g, x, t) => { if (t === 1) x.hitS[0].add('down'); }, 30);
check('cobrinha 2 jogadores: ninguém morre ao atravessar a parede', !g.over || !!g.winner);
g = auto('snake', { players: 1, walls: 'wall' }, () => {}, 30);
check('cobrinha: bater na parede encerra', g.over);
g = auto('tetris', {}, (g, x, t) => { if (t % 20 === 0) x.hitS[0].add('a'); }, 200);
check('tetris: empilhar até o topo encerra', g.over, g.hud());
// tetris: com o fundo quase cheio, completar uma linha soma pontos
{ const d = GAMES[0], gm = d.make({}, API), x = input(); for (let i = 0; i < 10; i++) gm.board[15 * 10 + i] = 0xffffff; gm.board[14 * 10] = 0x123456; x.hitS[0].add('a'); gm.update(1 / 60, x.I); x.hitS[0].clear(); for (let t = 0; t < 40; t++) gm.update(1 / 60, x.I);
  check('tetris: linha cheia é removida e o que está acima desce', gm.lines === 1 && gm.board[15 * 10] === 0x123456, `linhas=${gm.lines}`); }
g = auto('invasores', {}, (g, x, t) => { x.held[0].add('a'); x.ptr[0] = { x: 8 + 7 * Math.sin(t / 45), y: 15 }; }, 180);
check('invasores: atirar varrendo a tela elimina naves', g.score > 100, g.hud());
g = auto('corrida', {}, () => {}, 60);
check('corrida: parado na faixa acaba batendo', g.over, g.hud());
g = auto('passaro', {}, (g, x, t) => { g.draw(); let by = -1; for (let y = 0; y < 16; y++) if (F.px[y * 16 + 3] === 0xffd000) by = y; let top = -1, bot = -1; for (let c = 3; c < 12 && top < 0; c++) { const col = [...Array(16).keys()].map(y => F.px[y * 16 + c]); if (col[0] === 0x108020 || col[15] === 0x108020 || col.includes(0x60ff40) || col.includes(0x40c030)) { const free = col.map((v, y) => ![0x60ff40, 0x108020, 0x40c030, 0x0a5818].includes(v)); top = free.indexOf(true); bot = free.lastIndexOf(true); } } const tgt = top < 0 ? 8 : bot - 1; if (t === 0 || (by >= tgt && t % 6 === 0)) x.hitS[0].add('a'); }, 90);
check('pássaro: voando automático passa por canos', g.score >= 2, g.hud());
console.log(fail ? `\n${fail} FALHA(S)` : '\ntudo passou');
