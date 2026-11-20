// Отпечаток JS/TS/Vue без комментариев: node signature.cjs <ext> <node_modules> < файл
// Печатает md5 и число комментариев, стоящих первым узлом в v-if/v-else/слоте.
const crypto = require('crypto')
const { createRequire } = require('module')
const path = require('path')

const [ext, modules] = process.argv.slice(2)
const req = createRequire(path.join(modules, 'noop.js'))
const ts = req('typescript')
const src = require('fs').readFileSync(0, 'utf8')

function tsTokens(code, lang) {
  const kind = lang === 'js' ? ts.ScriptKind.JS : ts.ScriptKind.TS
  const sf = ts.createSourceFile('x.' + (lang || 'ts'), code, ts.ScriptTarget.Latest, false, kind)
  const out = []
  const visit = (n) => {
    const ch = n.getChildren(sf)
    if (!ch.length) out.push(n.kind + ':' + n.getText(sf))
    else ch.forEach(visit)
  }
  visit(sf)
  return out.join('\n')
}

function cssTokens(code) {
  return code.replace(/\/\*[\s\S]*?\*\//g, '').replace(/(^|[^:])\/\/.*$/gm, '$1').replace(/\s+/g, ' ').trim()
}

let branchFirstComments = 0
function tplTokens(nodes, parentBranch) {
  const out = []
  let first = true
  for (const n of nodes) {
    if (n.type === 3) {
      if (first && parentBranch) branchFirstComments++
      continue
    }
    if (n.type === 2) {
      const t = n.content.replace(/\s+/g, ' ').trim()
      if (t) out.push('T:' + t)
      first = false
      continue
    }
    first = false
    if (n.type === 1) {
      const props = (n.props || []).map((p) =>
        p.type === 6
          ? `${p.name}=${p.value ? p.value.content : ''}`
          : `${p.name}:${p.arg ? p.arg.content : ''}:${(p.modifiers || []).map((m) => m.content || m).join('.')}=${p.exp ? p.exp.content : ''}`,
      )
      const branch = (n.props || []).some((p) => p.type === 7 && ['if', 'else', 'else-if', 'slot'].includes(p.name))
        || (n.tag === 'template' && (n.props || []).some((p) => p.type === 7))
      out.push(`<${n.tag} ${props.join(' ')}>`, ...tplTokens(n.children || [], branch), `</${n.tag}>`)
    } else if (n.type === 5) {
      out.push('I:' + n.content.content)
    } else {
      out.push('N' + n.type)
    }
  }
  return out
}

let body
if (ext === '.vue') {
  const sfc = req('@vue/compiler-sfc')
  const { descriptor, errors } = sfc.parse(src, { comments: true })
  if (errors.length) {
    process.stdout.write('ошибка разбора 0')
    process.exit(0)
  }
  const parts = []
  if (descriptor.template) {
    const dom = req('@vue/compiler-dom')
    const ast = dom.parse(descriptor.template.content, { comments: true })
    parts.push('TPL', ...tplTokens(ast.children, false))
  }
  for (const s of [descriptor.script, descriptor.scriptSetup]) {
    if (s) parts.push('SCRIPT', tsTokens(s.content, s.lang === 'js' ? 'js' : 'ts'))
  }
  for (const s of descriptor.styles) parts.push('STYLE', cssTokens(s.content))
  body = parts.join('\n')
} else if (ext === '.scss' || ext === '.css') {
  body = cssTokens(src)
} else {
  body = tsTokens(src, ext === '.ts' || ext === '.tsx' ? 'ts' : 'js')
}
process.stdout.write(crypto.createHash('md5').update(body).digest('hex') + ' ' + branchFirstComments)
