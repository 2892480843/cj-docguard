// The native select remains the form field; the menu only improves its presentation.
let activeMenu = null;
let bound = false;
export const optionIsDisabled = option => option.disabled || (option.parentElement?.tagName==='OPTGROUP' && option.parentElement.disabled===true);
export function moveEnabled(options, current, key) {
  const enabled = options.map((option,index)=>option.disabled?-1:index).filter(index=>index>=0);
  if (!enabled.length) return -1;
  if (key === 'Home') return enabled[0];
  if (key === 'End') return enabled.at(-1);
  const position = enabled.indexOf(current);
  const direction = key === 'ArrowUp' ? -1 : 1;
  if (position < 0) return direction > 0 ? enabled[0] : enabled.at(-1);
  return enabled[(position + direction + enabled.length) % enabled.length];
}
export function matchOption(options, query, current) {
  const text = query.trim().toLocaleLowerCase();
  if (!text) return current;
  for (let offset=1; offset<=options.length; offset++) {
    const index = (Math.max(current,-1) + offset) % options.length;
    if (!options[index].disabled && options[index].label.toLocaleLowerCase().startsWith(text)) return index;
  }
  return current;
}
export function syncQueryFields(root){
 const form=root?.querySelector('#query-form');if(!form)return;
 const tool=form.elements.namedItem('tool')?.value;
 const needsEnvironment=tool==='get_verified_examples'||tool==='get_evidence';
 for(const name of ['sdk','platform','example']){
   const field=form.elements.namedItem(name);if(!field)continue;
   field.required=needsEnvironment&&name!=='example';
   field.disabled=!needsEnvironment||(name!=='example'&&![...field.options].some(option=>option.value));
   field.title=needsEnvironment?'选择要查询的环境':'公共接口查询不需要此条件';
   field.dispatchEvent(new Event('change'));
 }
}
export function enhanceSelects(root) {
  syncQueryFields(root);
  activeMenu?.close(false);
  if (!bound) {
    document.addEventListener('pointerdown',event=>{
      if (activeMenu && !activeMenu.wrapper.contains(event.target)) activeMenu.close(false);
    });
    document.addEventListener('scroll',event=>{
      if (activeMenu && !activeMenu.list.contains(event.target)) activeMenu.close(false);
    },true);
    window.addEventListener('resize',()=>activeMenu?.close(false));
    bound = true;
  }
  root.querySelectorAll('select').forEach((select,number)=>{
    if (select.dataset.enhanced) return;
    select.dataset.enhanced = 'true';
    const identity = select.id || `${select.form?.id||'select'}-${select.name||number}`;
    const label = select.getAttribute('aria-label') || Array.from(select.closest('label')?.childNodes||[]).filter(node=>node.nodeType===3).map(node=>node.textContent).join('').trim() || '选择选项';
    const wrapper = document.createElement('div');
    wrapper.className = `select-control${select.id==='project-picker'?' project-select':''}`;
    select.before(wrapper);wrapper.append(select);select.hidden=true;select.tabIndex=-1;
    const trigger = document.createElement('button');
    trigger.type='button';trigger.id=`${identity}-trigger`;
    trigger.className='select-trigger rounded-lg font-medium transition-colors';
    trigger.setAttribute('role','combobox');trigger.setAttribute('aria-label',label);
    trigger.setAttribute('aria-haspopup','listbox');trigger.setAttribute('aria-expanded','false');
    trigger.setAttribute('aria-controls',`${identity}-options`);
    const value = document.createElement('span');value.className='select-value';
    const chevron = document.createElement('span');chevron.className='select-chevron';chevron.setAttribute('aria-hidden','true');
    trigger.append(value,chevron);wrapper.append(trigger);
    const list = document.createElement('div');list.id=`${identity}-options`;
    list.className='select-options';list.hidden=true;list.setAttribute('role','listbox');list.setAttribute('aria-label',label);
    wrapper.append(list);
    const options = Array.from(select.options).map(option=>({label:option.label,disabled:optionIsDisabled(option)}));
    let current=select.selectedIndex, typeahead='',typedAt=0;
    const optionNodes=options.map((option,index)=>{
      const node=document.createElement('div');node.id=`${identity}-option-${index}`;
      node.className='select-option';node.setAttribute('role','option');
      node.setAttribute('aria-disabled',String(option.disabled));
      const text=document.createElement('span');text.textContent=option.label;
      const check=document.createElement('span');check.className='select-check';check.textContent='✓';check.setAttribute('aria-hidden','true');
      node.append(text,check);list.append(node);
      node.addEventListener('pointermove',()=>{if(!option.disabled)highlight(index,false)});
      node.addEventListener('pointerdown',event=>event.preventDefault());
      node.addEventListener('click',()=>{if(!option.disabled)commit(index)});
      return node;
    });
    function sync() {
      value.textContent=select.selectedOptions[0]?.label||'暂无可选项';
      trigger.title=select.title||value.textContent;trigger.setAttribute('aria-required',String(select.required));trigger.disabled=select.disabled||!options.some(option=>!option.disabled);
      optionNodes.forEach((node,index)=>node.setAttribute('aria-selected',String(index===select.selectedIndex)));
    }
    function highlight(index,scroll=true) {
      current=index;
      optionNodes.forEach((node,i)=>node.classList.toggle('highlighted',i===index));
      if(index>=0){trigger.setAttribute('aria-activedescendant',optionNodes[index].id);if(scroll)optionNodes[index].scrollIntoView({block:'nearest'});}
      else trigger.removeAttribute('aria-activedescendant');
    }
    function close(focus=true) {
      list.hidden=true;trigger.setAttribute('aria-expanded','false');trigger.removeAttribute('aria-activedescendant');
      wrapper.classList.remove('is-open');if(activeMenu?.trigger===trigger)activeMenu=null;
      if(focus&&trigger.isConnected)trigger.focus({preventScroll:true});
    }
    function open() {
      if(trigger.disabled)return;
      activeMenu?.close(false);sync();list.hidden=false;wrapper.classList.add('is-open');
      trigger.setAttribute('aria-expanded','true');activeMenu={wrapper,trigger,list,close};
      const rect=trigger.getBoundingClientRect(),width=Math.min(Math.max(rect.width,240),window.innerWidth-24);
      const below=window.innerHeight-rect.bottom-12,above=rect.top-12;
      const upwards=below<Math.min(options.length*42+12,320)&&above>below;
      list.style.width=`${width}px`;list.style.maxHeight=`${Math.max(80,Math.min(320,upwards?above:below))}px`;
      list.style.left=`${Math.max(12,Math.min(rect.left,window.innerWidth-width-12))}px`;
      list.style.top=`${upwards?Math.max(8,rect.top-list.getBoundingClientRect().height-6):rect.bottom+6}px`;
      highlight(options[select.selectedIndex]?.disabled?moveEnabled(options,-1,'Home'):select.selectedIndex);
    }
    function commit(index) {
      const changed=select.selectedIndex!==index;select.selectedIndex=index;sync();close();
      if(changed){select.dispatchEvent(new Event('input',{bubbles:true}));select.dispatchEvent(new Event('change',{bubbles:true}));}
    }
    trigger.addEventListener('click',()=>list.hidden?open():close());
    trigger.addEventListener('keydown',event=>{
      const key=event.key;
      if(key==='Tab'){close(false);return;}
      if(key==='Escape'&&!list.hidden){event.preventDefault();event.stopPropagation();close();return;}
      if(['ArrowDown','ArrowUp','Home','End'].includes(key)){
        event.preventDefault();if(list.hidden)open();highlight(moveEnabled(options,current,key));return;
      }
      if(key==='Enter'||key===' '){event.preventDefault();if(list.hidden)open();else if(current>=0)commit(current);return;}
      if(key.length===1&&!event.ctrlKey&&!event.metaKey&&!event.altKey){
        event.preventDefault();if(list.hidden)open();const now=Date.now();typeahead=now-typedAt>700?key:typeahead+key;typedAt=now;
        highlight(matchOption(options,typeahead,current));
      }
    });
    select.addEventListener('change',sync);sync();
  });
}
