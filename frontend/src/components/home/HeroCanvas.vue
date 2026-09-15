<script setup lang="ts">
import { onBeforeUnmount, onMounted, ref } from 'vue'

// トップページ ヒーロー背景。P&ID（配管計装図）のような直角配線と
// 計器盤のグリッドをモチーフにしたWebGLアニメーション。
// テキストの可読性を優先し、彩度・コントラストは抑える。

const canvasRef = ref<HTMLCanvasElement | null>(null)

let gl: WebGLRenderingContext | null = null
let program: WebGLProgram | null = null
let rafId = 0
let startTime = 0
let resizeObserver: ResizeObserver | null = null
let uTimeLoc: WebGLUniformLocation | null = null
let uResolutionLoc: WebGLUniformLocation | null = null
let uAspectLoc: WebGLUniformLocation | null = null

const VERTEX_SRC = `
attribute vec2 aPosition;
varying vec2 vUv;
void main() {
  vUv = aPosition * 0.5 + 0.5;
  gl_Position = vec4(aPosition, 0.0, 1.0);
}
`

const FRAGMENT_SRC = `
precision highp float;
varying vec2 vUv;
uniform float uTime;
uniform vec2 uResolution;
uniform float uAspect;

float segDist(vec2 p, vec2 a, vec2 b, out float t) {
  vec2 pa = p - a;
  vec2 ba = b - a;
  t = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
  return length(pa - ba * t);
}

vec3 traceLine(vec2 p, vec2 a, vec2 b, float phase, float speed, vec3 lineColor, vec3 pulseColor) {
  float t;
  float d = segDist(p, a, b, t);
  float lineMask = smoothstep(0.0022, 0.0, d);
  float pulse = smoothstep(0.16, 0.0, abs(fract(t - uTime * speed - phase) - 0.5));
  vec3 col = mix(lineColor * 0.36, mix(lineColor, pulseColor, 0.95), pulse);
  return col * lineMask;
}

float nodeRing(vec2 p, vec2 c, float r, float phase, float rate) {
  float d = abs(length(p - c) - r);
  float ring = smoothstep(0.007, 0.0, d);
  float breathe = 0.55 + 0.45 * sin(uTime * rate + phase);
  return ring * breathe;
}

void main() {
  vec2 uv = vUv;
  vec2 p = vec2(uv.x * uAspect, uv.y);
  vec2 pixel = uv * uResolution;

  vec3 colTop = vec3(0.086, 0.129, 0.169);
  vec3 colBottom = vec3(0.129, 0.192, 0.243);
  vec3 color = mix(colTop, colBottom, uv.y);

  vec2 gridUv = pixel / 46.0;
  vec2 gf = abs(fract(gridUv) - 0.5);
  float lineDist = min(gf.x, gf.y);
  float grid = smoothstep(0.02, 0.0, lineDist);
  color += grid * vec3(0.10, 0.16, 0.20);

  vec3 steel = vec3(0.36, 0.57, 0.70);
  vec3 amber = vec3(0.84, 0.55, 0.28);
  float a = uAspect;

  vec3 traces = vec3(0.0);
  traces += traceLine(p, vec2(0.56 * a, 0.10), vec2(0.56 * a, 0.42), 0.10, 0.14, steel, steel);
  traces += traceLine(p, vec2(0.56 * a, 0.42), vec2(0.80 * a, 0.42), 0.32, 0.13, steel, steel);
  traces += traceLine(p, vec2(0.80 * a, 0.42), vec2(0.80 * a, 0.78), 0.54, 0.12, steel, amber);
  traces += traceLine(p, vec2(0.38 * a, 0.68), vec2(0.66 * a, 0.68), 0.05, 0.15, steel, steel);
  traces += traceLine(p, vec2(0.66 * a, 0.44), vec2(0.66 * a, 0.68), 0.27, 0.15, steel, steel);
  traces += traceLine(p, vec2(0.90 * a, 0.16), vec2(0.90 * a, 0.56), 0.60, 0.135, steel, steel);
  traces += traceLine(p, vec2(0.64 * a, 0.56), vec2(0.90 * a, 0.56), 0.80, 0.135, steel, amber);
  traces += traceLine(p, vec2(0.30 * a, 0.24), vec2(0.30 * a, 0.50), 0.40, 0.15, steel, steel);
  color += traces * 1.0;

  color += nodeRing(p, vec2(0.56 * a, 0.10), 0.010, 0.0, 1.4) * steel * 0.9;
  color += nodeRing(p, vec2(0.80 * a, 0.78), 0.010, 1.6, 1.1) * steel * 0.9;
  color += nodeRing(p, vec2(0.90 * a, 0.16), 0.010, 3.0, 1.3) * steel * 0.9;
  color += nodeRing(p, vec2(0.30 * a, 0.24), 0.010, 4.2, 0.9) * steel * 0.9;
  color += nodeRing(p, vec2(0.66 * a, 0.44), 0.008, 2.3, 1.2) * steel * 0.7;

  float sweepAxis = uv.x * 0.85 + uv.y * 0.15;
  float sweepPos = fract(sweepAxis - uTime * 0.09);
  float sweep = smoothstep(0.12, 0.0, abs(sweepPos - 0.5));
  color += sweep * vec3(0.05, 0.10, 0.13);

  float vig = smoothstep(1.1, 0.2, length(uv - 0.5));
  color *= mix(0.55, 1.0, vig);

  gl_FragColor = vec4(color, 1.0);
}
`

function compileShader(context: WebGLRenderingContext, type: number, source: string) {
  const shader = context.createShader(type)
  if (!shader) return null
  context.shaderSource(shader, source)
  context.compileShader(shader)
  if (!context.getShaderParameter(shader, context.COMPILE_STATUS)) {
    console.error('HeroCanvas shader compile error:', context.getShaderInfoLog(shader))
    context.deleteShader(shader)
    return null
  }
  return shader
}

function resize() {
  const canvas = canvasRef.value
  if (!canvas || !gl) return
  const dpr = Math.min(window.devicePixelRatio || 1, 2)
  const width = Math.max(1, Math.round(canvas.clientWidth * dpr))
  const height = Math.max(1, Math.round(canvas.clientHeight * dpr))
  if (canvas.width !== width || canvas.height !== height) {
    canvas.width = width
    canvas.height = height
    gl.viewport(0, 0, width, height)
  }
}

function render(time: number) {
  if (!gl || !program || !canvasRef.value) return
  resize()
  if (!startTime) startTime = time
  const elapsed = (time - startTime) / 1000
  gl.uniform1f(uTimeLoc, elapsed)
  gl.uniform2f(uResolutionLoc, canvasRef.value.width, canvasRef.value.height)
  gl.uniform1f(uAspectLoc, canvasRef.value.width / canvasRef.value.height)
  gl.drawArrays(gl.TRIANGLES, 0, 3)
  rafId = requestAnimationFrame(render)
}

onMounted(() => {
  const canvas = canvasRef.value
  if (!canvas) return

  gl = (canvas.getContext('webgl') ||
    canvas.getContext('experimental-webgl')) as WebGLRenderingContext | null
  if (!gl) return

  const vertexShader = compileShader(gl, gl.VERTEX_SHADER, VERTEX_SRC)
  const fragmentShader = compileShader(gl, gl.FRAGMENT_SHADER, FRAGMENT_SRC)
  if (!vertexShader || !fragmentShader) return

  program = gl.createProgram()
  if (!program) return
  gl.attachShader(program, vertexShader)
  gl.attachShader(program, fragmentShader)
  gl.linkProgram(program)
  if (!gl.getProgramParameter(program, gl.LINK_STATUS)) {
    console.error('HeroCanvas program link error:', gl.getProgramInfoLog(program))
    return
  }
  gl.useProgram(program)

  const positions = new Float32Array([-1, -1, 3, -1, -1, 3])
  const buffer = gl.createBuffer()
  gl.bindBuffer(gl.ARRAY_BUFFER, buffer)
  gl.bufferData(gl.ARRAY_BUFFER, positions, gl.STATIC_DRAW)

  const aPosition = gl.getAttribLocation(program, 'aPosition')
  gl.enableVertexAttribArray(aPosition)
  gl.vertexAttribPointer(aPosition, 2, gl.FLOAT, false, 0, 0)

  uTimeLoc = gl.getUniformLocation(program, 'uTime')
  uResolutionLoc = gl.getUniformLocation(program, 'uResolution')
  uAspectLoc = gl.getUniformLocation(program, 'uAspect')

  resize()

  const prefersReducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches
  if (prefersReducedMotion) {
    gl.uniform1f(uTimeLoc, 6)
    gl.uniform2f(uResolutionLoc, canvas.width, canvas.height)
    gl.uniform1f(uAspectLoc, canvas.width / canvas.height)
    gl.drawArrays(gl.TRIANGLES, 0, 3)
    return
  }

  resizeObserver = new ResizeObserver(() => resize())
  resizeObserver.observe(canvas)

  rafId = requestAnimationFrame(render)
})

onBeforeUnmount(() => {
  if (rafId) cancelAnimationFrame(rafId)
  resizeObserver?.disconnect()
})
</script>

<template>
  <canvas ref="canvasRef" class="pk-hero-canvas" aria-hidden="true"></canvas>
</template>

<style scoped>
.pk-hero-canvas {
  position: absolute;
  inset: 0;
  width: 100%;
  height: 100%;
  display: block;
}
</style>
