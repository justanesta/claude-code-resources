# DOM Manipulation Reference

Comprehensive reference for modern DOM APIs and patterns in web development.

---

## Element Selection

### querySelector / querySelectorAll

```javascript
// Single element — returns first match or null
const header = document.querySelector("header.main-nav");
const submitBtn = document.querySelector('[data-action="submit"]');

// Multiple elements — returns static NodeList
const allCards = document.querySelectorAll(".card");
const inputs = document.querySelectorAll('input[type="text"], input[type="email"]');

// Scoped queries — search within a subtree
const form = document.querySelector("#signup-form");
const emailField = form.querySelector('[name="email"]');

// Convert NodeList to Array for full array method access
const cardArray = [...document.querySelectorAll(".card")];
const visibleCards = cardArray.filter((card) => !card.hidden);
```

### closest — Traverse up the DOM

```javascript
// Find nearest ancestor matching a selector
function handleClick(event) {
  const card = event.target.closest(".card");
  if (!card) return;

  const cardId = card.dataset.cardId;
  openCard(cardId);
}

// Check if element is inside a specific container
function isInsideModal(element) {
  return element.closest('[role="dialog"]') !== null;
}
```

### matches — Test element against selector

```javascript
// Check if element matches a selector
function isInteractive(element) {
  return element.matches('a, button, input, select, textarea, [tabindex], [role="button"]');
}
```

---

## Event Delegation

Attach a single listener to a parent and use event bubbling to handle child events.

### Basic delegation pattern

```javascript
// Instead of attaching listeners to every button
const list = document.querySelector("#task-list");

list.addEventListener("click", (event) => {
  const deleteBtn = event.target.closest('[data-action="delete"]');
  if (deleteBtn) {
    const taskItem = deleteBtn.closest(".task-item");
    deleteTask(taskItem.dataset.taskId);
    return;
  }

  const editBtn = event.target.closest('[data-action="edit"]');
  if (editBtn) {
    const taskItem = editBtn.closest(".task-item");
    editTask(taskItem.dataset.taskId);
    return;
  }
});
```

### Reusable delegation helper

```javascript
function delegate(parent, selector, eventType, handler) {
  parent.addEventListener(eventType, (event) => {
    const target = event.target.closest(selector);
    if (target && parent.contains(target)) {
      handler.call(target, event, target);
    }
  });
}

// Usage
const container = document.querySelector("#app");
delegate(container, ".card", "click", (event, card) => {
  openCard(card.dataset.id);
});

delegate(container, "form", "submit", (event, form) => {
  event.preventDefault();
  handleFormSubmit(new FormData(form));
});
```

---

## DOM Modification

### Creating elements

```javascript
// Create complex element structures
function createCard({ title, description, imageUrl }) {
  const card = document.createElement("article");
  card.className = "card";
  card.innerHTML = `
    <img class="card__image" src="${imageUrl}" alt="" loading="lazy" />
    <div class="card__body">
      <h3 class="card__title"></h3>
      <p class="card__description"></p>
    </div>
  `;
  // Set text content safely (prevents XSS)
  card.querySelector(".card__title").textContent = title;
  card.querySelector(".card__description").textContent = description;
  return card;
}

// Batch DOM insertions with DocumentFragment
function renderCards(cards, container) {
  const fragment = document.createDocumentFragment();
  for (const cardData of cards) {
    fragment.appendChild(createCard(cardData));
  }
  container.appendChild(fragment);
}
```

### Modern insertion methods

```javascript
const container = document.querySelector("#list");

// Insert adjacent HTML/elements
container.insertAdjacentHTML("beforeend", "<li>New item</li>");

// Prepend/append multiple nodes
container.prepend(newFirstChild);
container.append(newLastChild, anotherChild);

// Replace children entirely
container.replaceChildren(...newChildren);

// Replace or remove elements
oldElement.replaceWith(newElement);
element.remove();
```

---

## IntersectionObserver

Observe when elements enter or leave the viewport.

### Lazy loading images

```javascript
function createLazyLoader() {
  const observer = new IntersectionObserver(
    (entries) => {
      for (const entry of entries) {
        if (entry.isIntersecting) {
          const img = entry.target;
          img.src = img.dataset.src;
          img.removeAttribute("data-src");
          observer.unobserve(img);
        }
      }
    },
    { rootMargin: "200px 0px" } // Start loading 200px before visible
  );

  document.querySelectorAll("img[data-src]").forEach((img) => observer.observe(img));
  return observer;
}
```

### Infinite scroll

```javascript
function createInfiniteScroll(sentinel, loadMore) {
  let loading = false;

  const observer = new IntersectionObserver(
    async ([entry]) => {
      if (entry.isIntersecting && !loading) {
        loading = true;
        try {
          const hasMore = await loadMore();
          if (!hasMore) observer.disconnect();
        } finally {
          loading = false;
        }
      }
    },
    { rootMargin: "0px 0px 400px 0px" }
  );

  observer.observe(sentinel);
  return () => observer.disconnect();
}

// Usage
const sentinel = document.querySelector("#scroll-sentinel");
const cleanup = createInfiniteScroll(sentinel, async () => {
  const items = await fetchNextPage();
  renderItems(items);
  return items.length > 0; // Return false when no more items
});
```

---

## MutationObserver

Observe changes to the DOM tree.

### Watch for dynamic content

```javascript
function observeChildChanges(target, callback) {
  const observer = new MutationObserver((mutations) => {
    for (const mutation of mutations) {
      if (mutation.type === "childList") {
        const added = [...mutation.addedNodes].filter((n) => n.nodeType === Node.ELEMENT_NODE);
        const removed = [...mutation.removedNodes].filter((n) => n.nodeType === Node.ELEMENT_NODE);
        if (added.length || removed.length) {
          callback({ added, removed });
        }
      }
    }
  });

  observer.observe(target, { childList: true, subtree: true });
  return () => observer.disconnect();
}

// Usage — auto-initialize components when added to DOM
const cleanup = observeChildChanges(document.body, ({ added }) => {
  for (const element of added) {
    if (element.matches("[data-component]")) {
      initializeComponent(element);
    }
  }
});
```

---

## ResizeObserver

Observe element size changes for responsive components.

```javascript
function observeResize(element, callback) {
  const observer = new ResizeObserver((entries) => {
    for (const entry of entries) {
      const { width, height } = entry.contentRect;
      callback({ width, height, element: entry.target });
    }
  });

  observer.observe(element);
  return () => observer.disconnect();
}

// Responsive component that adapts layout based on container width
const cleanup = observeResize(container, ({ width }) => {
  container.classList.toggle("compact", width < 400);
  container.classList.toggle("medium", width >= 400 && width < 800);
  container.classList.toggle("wide", width >= 800);
});
```

---

## Performance Best Practices

- **Batch DOM reads and writes** — read all measurements first, then apply all mutations to avoid layout thrashing
- **Use `DocumentFragment`** for batch insertions instead of appending elements one at a time
- **Prefer `textContent` over `innerHTML`** for text-only updates (safer and faster)
- **Disconnect observers** when no longer needed to prevent memory leaks
- **Use `loading="lazy"`** on images and iframes for native lazy loading

source: MDN Web Docs, web.dev, JavaScript.info
