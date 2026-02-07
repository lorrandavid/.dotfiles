---
name: angular-router-first-methodology
description: A step-by-step guide to implementing Router-First Architecture in Angular applications for scalable and maintainable codebases.
---

## Core Concept

**Router-First Architecture** is a methodology that enforces designing your application's routing structure BEFORE implementing components. This approach ensures high-level thinking, team consensus, and scalable architecture from day one.

---

## Why Router-First?

Traditional development often starts with components, leading to:
- ❌ Unclear application structure
- ❌ Tight coupling between features
- ❌ Difficult to refactor later
- ❌ Hard to parallelize team work
- ❌ Performance issues at scale

Router-First solves this by:
- ✅ Forcing architectural decisions early
- ✅ Creating clear feature boundaries
- ✅ Enabling lazy loading from the start
- ✅ Facilitating team collaboration
- ✅ Making the app structure visible in code

---

## The 7 Steps

### Step 1: Develop a Roadmap and Scope

**Goal:** Define what features your application needs

**Process:**
1. List all user-facing features
2. Identify MVP vs. future features
3. Group related functionality
4. Define user roles and permissions

**Example:**
```
E-commerce App Roadmap:

Phase 1 (MVP):
- Product browsing
- Shopping cart
- Checkout
- User authentication

Phase 2:
- Order history
- Product reviews
- Wishlist
- Admin panel

Phase 3:
- Analytics dashboard
- Inventory management
- Customer support
```

**Output:** Feature list with priorities

---

### Step 2: Design with Lazy Loading in Mind

**Goal:** Plan bundle structure for optimal performance

**Process:**
1. Each major feature = separate lazy-loaded module
2. Identify shared dependencies
3. Plan loading strategies
4. Set bundle size budgets

**Example:**
```typescript
// Bundle planning
Initial Load (Critical Path):
- Authentication (50 KB)
- Layout shell (30 KB)
- Core services (40 KB)
Total: 120 KB ✅

Lazy Loaded Features:
- Dashboard (60 KB)
- Products (80 KB) 
- Orders (45 KB)
- Admin (120 KB)

Strategy:
- Preload Dashboard after login
- Lazy load others on-demand
- Code split large features
```

**Anti-pattern:**
```typescript
// ❌ BAD: Everything imported at root
import { DashboardModule } from './dashboard';
import { ProductsModule } from './products';
import { OrdersModule } from './orders';
```

**Best Practice:**
```typescript
// ✅ GOOD: Lazy loaded via routes
{
  path: 'dashboard',
  loadChildren: () => import('./dashboard/dashboard.routes')
}
```

---

### Step 3: Implement Walking-Skeleton Navigation

**Goal:** Create navigable shell with placeholder content

**Process:**
1. Define all routes in app.routes.ts
2. Create shell components (empty templates)
3. Verify navigation works
4. Add breadcrumbs and titles

**Example:**
```typescript
// app.routes.ts - Walking skeleton
export const routes: Routes = [
  {
    path: '',
    redirectTo: '/dashboard',
    pathMatch: 'full'
  },
  {
    path: 'dashboard',
    loadComponent: () => import('./features/dashboard/dashboard.component')
      .then(m => m.DashboardComponent),
    data: { breadcrumb: 'Dashboard' }
  },
  {
    path: 'products',
    loadComponent: () => import('./features/products/products.component')
      .then(m => m.ProductsComponent),
    data: { breadcrumb: 'Products' }
  },
  {
    path: 'orders',
    loadComponent: () => import('./features/orders/orders.component')
      .then(m => m.OrdersComponent),
    data: { breadcrumb: 'Orders' }
  }
];
```

```typescript
// dashboard.component.ts - Shell component
@Component({
  selector: 'app-dashboard',
  standalone: true,
  template: `
    <h1>Dashboard</h1>
    <p>Coming soon...</p>
  `
})
export class DashboardComponent {}
```

**Benefit:** Team can navigate the app before any features are implemented

---

### Step 4: Achieve Stateless, Data-Driven Design

**Goal:** Components receive data, don't manage global state

**Process:**
1. Services handle state and HTTP
2. Components receive data via inputs/signals
3. Components emit events, not side effects
4. Use observables for async data

**Example:**

```typescript
// ❌ BAD: Component manages state
@Component({...})
export class ProductListComponent {
  products: Product[] = [];
  
  constructor(private http: HttpClient) {
    this.http.get('/api/products').subscribe(data => {
      this.products = data;
    });
  }
}
```

```typescript
// ✅ GOOD: Service manages state
@Injectable({ providedIn: 'root' })
export class ProductService {
  private products$ = new BehaviorSubject<Product[]>([]);
  
  getProducts(): Observable<Product[]> {
    return this.http.get<Product[]>('/api/products').pipe(
      tap(products => this.products$.next(products))
    );
  }
}

@Component({...})
export class ProductListComponent {
  products$ = inject(ProductService).getProducts();
}
```

---

### Step 5: Enforce Decoupled Component Architecture

**Goal:** Separate smart (container) and dumb (presentational) components

**Smart Components:**
- Manage data fetching
- Handle business logic
- Communicate with services
- Located in feature folders

**Dumb Components:**
- Receive data via @Input
- Emit events via @Output
- No business logic
- Located in shared folder

**Example:**

```typescript
// Smart component (container)
@Component({
  selector: 'app-product-list',
  template: `
    @for (product of products(); track product.id) {
      <app-product-card 
        [product]="product"
        (addToCart)="handleAddToCart($event)"
      />
    }
  `
})
export class ProductListComponent {
  private productService = inject(ProductService);
  products = toSignal(this.productService.getProducts());
  
  handleAddToCart(productId: string) {
    this.cartService.addItem(productId);
  }
}

// Dumb component (presentational)
@Component({
  selector: 'app-product-card',
  template: `
    <div class="card">
      <h3>{{ product.name }}</h3>
      <p>{{ product.price | currency }}</p>
      <button (click)="addToCart.emit(product.id)">
        Add to Cart
      </button>
    </div>
  `
})
export class ProductCardComponent {
  @Input({ required: true }) product!: Product;
  @Output() addToCart = new EventEmitter<string>();
}
```

---

### Step 6: Differentiate User Controls vs Components

**Goal:** Clear separation between reusable UI and feature-specific components

**User Controls (Shared):**
- Generic UI elements
- No business logic
- Highly reusable
- Location: `shared/components/`

**Feature Components:**
- Feature-specific logic
- Use shared controls
- Business logic included
- Location: `features/<feature>/components/`

**Example Structure:**

```
shared/components/          # User Controls
├── button/
├── input/
├── card/
├── modal/
└── data-table/

features/products/          # Feature Components
├── product-list/
├── product-detail/
├── product-form/
└── product-search/
```

---

### Step 7: Maximize Code Reuse

**Goal:** DRY principle with TypeScript and ES features

**Techniques:**

1. **Shared Utilities**
```typescript
// shared/utils/date.utils.ts
export function formatDate(date: Date): string {
  return date.toLocaleDateString('en-US');
}
```

2. **Shared Interfaces**
```typescript
// core/models/api-response.interface.ts
export interface ApiResponse<T> {
  data: T;
  message: string;
  status: number;
}
```

3. **Base Classes (use sparingly)**
```typescript
// core/base/base-component.ts
export abstract class BaseComponent implements OnDestroy {
  protected destroy$ = new Subject<void>();
  
  ngOnDestroy() {
    this.destroy$.next();
    this.destroy$.complete();
  }
}
```

4. **Mixins**
```typescript
// shared/mixins/timestamp.mixin.ts
export function WithTimestamp<T extends Constructor>(Base: T) {
  return class extends Base {
    createdAt = new Date();
    updatedAt = new Date();
  };
}
```

---

## Real-World Application

### Case Study: E-commerce Platform

**Team:** 15 developers  
**Timeline:** 6 months  
**Features:** 12 major features

**Router-First Implementation:**

1. **Week 1:** Route planning
   - Defined all 12 features as routes
   - Created walking skeleton
   - Team reviewed and agreed on structure

2. **Week 2-3:** Core setup
   - Implemented auth guards
   - Set up core services
   - Created shared components

3. **Week 4-24:** Parallel development
   - 3 teams worked on different features simultaneously
   - No merge conflicts (clear boundaries)
   - Easy to track progress (routes visible)

4. **Result:**
   - On-time delivery
   - 185 KB initial bundle
   - 45 KB average feature bundle
   - Easy onboarding for new devs

---

## Common Mistakes

### 1. Starting with Components
```typescript
// ❌ WRONG ORDER
1. Build dashboard component
2. Build product list component  
3. Figure out routing later

// ✅ CORRECT ORDER
1. Design routes
2. Create shell components
3. Implement features
```

### 2. Tight Coupling
```typescript
// ❌ BAD: Direct component dependencies
export class DashboardComponent {
  constructor(private productList: ProductListComponent) {}
}

// ✅ GOOD: Service-based communication
export class DashboardComponent {
  constructor(private productService: ProductService) {}
}
```

### 3. Ignoring Lazy Loading
```typescript
// ❌ BAD: Eager loading everything
imports: [
  DashboardModule,
  ProductsModule,
  OrdersModule
]

// ✅ GOOD: Lazy load features
{
  path: 'dashboard',
  loadChildren: () => import('./dashboard/dashboard.routes')
}
```

---

## Checklist

Before claiming Router-First compliance:

- [ ] Routes defined before component implementation
- [ ] All features lazy loaded (except critical path)
- [ ] Walking skeleton navigation works
- [ ] Smart/Dumb component separation
- [ ] Services manage state, not components
- [ ] Shared components in shared folder
- [ ] Feature components in feature folders
- [ ] Clear team agreement on structure
- [ ] Bundle size budgets defined
- [ ] Documentation of routing decisions

---

## Summary

Router-First Architecture is about **planning before building**. By designing routes first, you create a scalable, maintainable, and performant Angular application that grows with your team.

**Key Takeaway:** If you can see your entire application structure by looking at app.routes.ts, you're doing it right.