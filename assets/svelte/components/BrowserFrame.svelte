<div class="flex-1 flex flex-col" data-testid="fake-browser">
  <div class="bg-base-200 border-b border-base-300 border-solid rounded-t-xl h-12 px-3.5 flex" data-testid="address-bar">
    <div class="py-2">
      <span class="inline-block h-2 w-2 ml-2 rounded-full bg-red-800"></span>
      <span class="inline-block h-2 w-2 ml-2 rounded-full bg-amber-400"></span>
      <span class="inline-block h-2 w-2 ml-2 rounded-full bg-lime-600"></span>
    </div>
    <div class="py-3">
      <!-- D | T | P or some selector to choose desktop, tablet or phone viewport size-->
    </div>
  </div>
  <slot />
</div>
