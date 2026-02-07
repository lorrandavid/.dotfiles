---
name: angular-enterprise-patterns
description: Proven architectural patterns for building scalable Angular applications in enterprise environments with teams of 5-100+ developers.
---

# Core Concept

Proven architectural patterns for building scalable Angular applications in enterprise environments with teams of 5-100+ developers.

---

## Core Principles

1. **Separation of Concerns** - Each piece of code has one responsibility
2. **Single Source of Truth** - State lives in one place
3. **Consistency** - Follow patterns religiously
4. **Scalability** - Design for 10x growth
5. **Maintainability** - Code should be easy to change

---

## Pattern 1: Core-Shared-Features Structure

### Overview
Organize code into three main categories based on scope and reusability.

### The Three Folders

```
src/app/
├── core/          # App-wide singletons (loaded once)
├── shared/        # Reusable components/utilities
└── features/      # Feature modules (lazy loaded)
```

### Core Module Rules

**What belongs in core:**
- ✅ Singleton services (AuthService, ApiService, CacheService)
- ✅ HTTP interceptors (auth, error handling, retry)
- ✅ Route guards (authentication, authorization)
- ✅ Global error handlers
- ✅ App-wide models and interfaces
- ✅ Constants and configuration

**What does NOT belong:**
- ❌ UI components
- ❌ Feature-specific services
- ❌ Reusable utilities (those go in shared)

**Example:**
```typescript
// core/services/auth.service.ts
@Injectable({ providedIn: 'root' })
export class AuthService {
  private currentUser$ = new BehaviorSubject<User | null>(null);
  
  login(credentials: Credentials): Observable<User> {
    return this.http.post<User>('/api/auth/login', credentials).pipe(
      tap(user => this.currentUser$.next(user))
    );
  }
  
  getCurrentUser(): Observable<User | null> {
    return this.currentUser$.asObservable();
  }
}
```

### Shared Module Rules

**What belongs in shared:**
- ✅ Dumb/presentational components (buttons, cards, modals)
- ✅ Custom directives (tooltips, permissions, auto-focus)
- ✅ Custom pipes (formatting, filtering)
- ✅ Utility functions (date helpers, validators)
- ✅ Common interfaces used across features

**What does NOT belong:**
- ❌ Business logic
- ❌ HTTP calls
- ❌ Feature-specific components

**Example:**
```typescript
// shared/components/data-table/data-table.component.ts
@Component({
  selector: 'app-data-table',
  standalone: true,
  template: `
    <table>
      <thead>
        <tr>
          @for (column of columns(); track column.key) {
            <th>{{ column.label }}</th>
          }
        </tr>
      </thead>
      <tbody>
        @for (row of data(); track row.id) {
          <tr>
            @for (column of columns(); track column.key) {
              <td>{{ row[column.key] }}</td>
            }
          </tr>
        }
      </tbody>
    </table>
  `
})
export class DataTableComponent {
  columns = input.required<Column[]>();
  data = input.required<any[]>();
}
```

### Features Module Rules

**What belongs in features:**
- ✅ Feature-specific components (smart + dumb)
- ✅ Feature-specific services
- ✅ Feature-specific models
- ✅ Feature routing configuration

**Structure:**
```
features/
└── products/
    ├── components/           # Feature components
    │   ├── product-list/
    │   ├── product-detail/
    │   └── product-form/
    ├── services/             # Feature services
    │   └── product.service.ts
    ├── models/               # Feature models
    │   └── product.interface.ts
    ├── products.routes.ts    # Feature routes
    └── products.component.ts # Container component
```

---

## Pattern 2: Smart and Dumb Components

### Overview
Separate components that manage data (smart) from components that display data (dumb).

### Smart Components (Containers)

**Characteristics:**
- Communicate with services
- Manage state
- Handle business logic
- Usually top-level feature components

**Example:**
```typescript
// features/products/product-list.component.ts
@Component({
  selector: 'app-product-list',
  template: `
    <app-search-bar (search)="handleSearch($event)" />
    
    @if (loading()) {
      <app-loading-spinner />
    } @else if (error()) {
      <app-error-message [error]="error()" />
    } @else {
      @for (product of products(); track product.id) {
        <app-product-card 
          [product]="product"
          (edit)="handleEdit($event)"
          (delete)="handleDelete($event)"
        />
      }
    }
  `
})
export class ProductListComponent {
  private productService = inject(ProductService);
  
  products = signal<Product[]>([]);
  loading = signal(false);
  error = signal<string | null>(null);
  
  ngOnInit() {
    this.loadProducts();
  }
  
  loadProducts() {
    this.loading.set(true);
    this.productService.getProducts().pipe(
      takeUntilDestroyed()
    ).subscribe({
      next: products => {
        this.products.set(products);
        this.loading.set(false);
      },
      error: err => {
        this.error.set(err.message);
        this.loading.set(false);
      }
    });
  }
  
  handleEdit(id: string) {
    this.router.navigate(['/products', id, 'edit']);
  }
  
  handleDelete(id: string) {
    if (confirm('Delete this product?')) {
      this.productService.delete(id).subscribe();
    }
  }
}
```

### Dumb Components (Presentational)

**Characteristics:**
- Receive data via @Input or input()
- Emit events via @Output or output()
- No service dependencies
- Highly reusable
- Easy to test

**Example:**
```typescript
// shared/components/product-card.component.ts
@Component({
  selector: 'app-product-card',
  standalone: true,
  imports: [CurrencyPipe],
  template: `
    <div class="card">
      <img [src]="product().image" [alt]="product().name" />
      <h3>{{ product().name }}</h3>
      <p>{{ product().price | currency }}</p>
      <div class="actions">
        <button (click)="edit.emit(product().id)">Edit</button>
        <button (click)="delete.emit(product().id)">Delete</button>
      </div>
    </div>
  `
})
export class ProductCardComponent {
  product = input.required<Product>();
  edit = output<string>();
  delete = output<string>();
}
```

---

## Pattern 3: Service Layer Architecture

### Overview
Organize services by responsibility: data access, business logic, and state management.

### Data Services

**Purpose:** HTTP communication only

```typescript
// core/services/api.service.ts
@Injectable({ providedIn: 'root' })
export class ApiService {
  private http = inject(HttpClient);
  private baseUrl = environment.apiUrl;
  
  get<T>(endpoint: string): Observable<T> {
    return this.http.get<T>(`${this.baseUrl}/${endpoint}`);
  }
  
  post<T>(endpoint: string, data: any): Observable<T> {
    return this.http.post<T>(`${this.baseUrl}/${endpoint}`, data);
  }
}
```

### Business Services

**Purpose:** Business logic and domain operations

```typescript
// features/products/services/product.service.ts
@Injectable({ providedIn: 'root' })
export class ProductService {
  private api = inject(ApiService);
  
  getProducts(): Observable<Product[]> {
    return this.api.get<Product[]>('products').pipe(
      map(products => this.enrichProducts(products))
    );
  }
  
  private enrichProducts(products: Product[]): Product[] {
    return products.map(p => ({
      ...p,
      displayPrice: this.formatPrice(p.price),
      inStock: p.quantity > 0
    }));
  }
  
  private formatPrice(price: number): string {
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: 'USD'
    }).format(price);
  }
}
```

### State Services

**Purpose:** Manage application state

```typescript
// features/cart/services/cart-state.service.ts
@Injectable({ providedIn: 'root' })
export class CartStateService {
  private itemsSubject = new BehaviorSubject<CartItem[]>([]);
  
  // Public observable
  items$ = this.itemsSubject.asObservable();
  
  // Computed values
  total$ = this.items$.pipe(
    map(items => items.reduce((sum, item) => sum + item.price * item.quantity, 0))
  );
  
  itemCount$ = this.items$.pipe(
    map(items => items.reduce((count, item) => count + item.quantity, 0))
  );
  
  addItem(item: CartItem) {
    const current = this.itemsSubject.value;
    this.itemsSubject.next([...current, item]);
  }
  
  removeItem(id: string) {
    const current = this.itemsSubject.value;
    this.itemsSubject.next(current.filter(item => item.id !== id));
  }
  
  clear() {
    this.itemsSubject.next([]);
  }
}
```

---

## Pattern 4: Facade Pattern

### Overview
Create a single entry point for complex subsystems.

### Use Case
When a feature has multiple related services that components need to interact with.

**Example:**
```typescript
// features/checkout/services/checkout.facade.ts
@Injectable({ providedIn: 'root' })
export class CheckoutFacade {
  private cartService = inject(CartService);
  private paymentService = inject(PaymentService);
  private shippingService = inject(ShippingService);
  private orderService = inject(OrderService);
  
  // Expose simplified API
  cart$ = this.cartService.items$;
  total$ = this.cartService.total$;
  shippingMethods$ = this.shippingService.getMethods();
  
  processCheckout(data: CheckoutData): Observable<Order> {
    return this.validateCart().pipe(
      switchMap(() => this.calculateShipping(data.shippingMethod)),
      switchMap(shipping => this.processPayment(data.payment, shipping)),
      switchMap(payment => this.createOrder({ ...data, payment })),
      tap(() => this.cartService.clear())
    );
  }
  
  private validateCart(): Observable<boolean> {
    return this.cart$.pipe(
      take(1),
      map(items => items.length > 0),
      tap(valid => { if (!valid) throw new Error('Cart is empty'); })
    );
  }
  
  private calculateShipping(method: string): Observable<number> {
    return this.shippingService.calculate(method);
  }
  
  private processPayment(payment: PaymentInfo, shipping: number): Observable<PaymentResult> {
    return this.total$.pipe(
      take(1),
      switchMap(total => this.paymentService.charge({
        ...payment,
        amount: total + shipping
      }))
    );
  }
  
  private createOrder(data: OrderData): Observable<Order> {
    return this.orderService.create(data);
  }
}

// Component uses facade instead of multiple services
@Component({...})
export class CheckoutComponent {
  private facade = inject(CheckoutFacade);
  
  cart$ = this.facade.cart$;
  total$ = this.facade.total$;
  
  checkout(data: CheckoutData) {
    this.facade.processCheckout(data).subscribe({
      next: order => this.router.navigate(['/order-confirmation', order.id]),
      error: err => this.showError(err)
    });
  }
}
```

---

## Pattern 5: Error Handling Strategy

### Global Error Handler

```typescript
// core/handlers/global-error.handler.ts
@Injectable()
export class GlobalErrorHandler implements ErrorHandler {
  private logger = inject(LoggerService);
  private notification = inject(NotificationService);
  
  handleError(error: Error | HttpErrorResponse) {
    if (error instanceof HttpErrorResponse) {
      // Server error
      this.handleHttpError(error);
    } else {
      // Client error
      this.handleClientError(error);
    }
  }
  
  private handleHttpError(error: HttpErrorResponse) {
    const message = this.getErrorMessage(error);
    this.notification.showError(message);
    this.logger.error('HTTP Error', { error, url: error.url });
  }
  
  private handleClientError(error: Error) {
    this.notification.showError('An unexpected error occurred');
    this.logger.error('Client Error', { error, stack: error.stack });
  }
  
  private getErrorMessage(error: HttpErrorResponse): string {
    if (error.status === 0) {
      return 'No internet connection';
    } else if (error.status === 401) {
      return 'Session expired. Please login again.';
    } else if (error.status === 403) {
      return 'You do not have permission to perform this action';
    } else if (error.status >= 500) {
      return 'Server error. Please try again later.';
    }
    return error.error?.message || 'An error occurred';
  }
}
```

### HTTP Error Interceptor

```typescript
// core/interceptors/error.interceptor.ts
export const errorInterceptor: HttpInterceptorFn = (req, next) => {
  return next(req).pipe(
    catchError((error: HttpErrorResponse) => {
      if (error.status === 401) {
        // Redirect to login
        inject(Router).navigate(['/login']);
      }
      return throwError(() => error);
    })
  );
};
```

---

## Pattern 6: Feature Flags

### Overview
Control feature visibility without deploying new code.

```typescript
// core/services/feature-flag.service.ts
@Injectable({ providedIn: 'root' })
export class FeatureFlagService {
  private flags = signal<Record<string, boolean>>({
    'new-dashboard': false,
    'beta-checkout': true,
    'admin-analytics': false
  });
  
  isEnabled(feature: string): boolean {
    return this.flags()[feature] ?? false;
  }
  
  enable(feature: string) {
    this.flags.update(flags => ({ ...flags, [feature]: true }));
  }
  
  disable(feature: string) {
    this.flags.update(flags => ({ ...flags, [feature]: false }));
  }
}

// Usage in component
@Component({
  template: `
    @if (showNewDashboard()) {
      <app-new-dashboard />
    } @else {
      <app-old-dashboard />
    }
  `
})
export class DashboardComponent {
  private featureFlags = inject(FeatureFlagService);
  showNewDashboard = computed(() => this.featureFlags.isEnabled('new-dashboard'));
}

// Usage in routes
{
  path: 'beta',
  loadComponent: () => import('./beta.component'),
  canActivate: [() => inject(FeatureFlagService).isEnabled('beta-features')]
}
```

---

## Pattern 7: Caching Strategy

### Service-Level Cache

```typescript
// core/services/cache.service.ts
@Injectable({ providedIn: 'root' })
export class CacheService {
  private cache = new Map<string, { data: any; timestamp: number }>();
  private TTL = 5 * 60 * 1000; // 5 minutes
  
  get<T>(key: string): T | null {
    const cached = this.cache.get(key);
    if (!cached) return null;
    
    if (Date.now() - cached.timestamp > this.TTL) {
      this.cache.delete(key);
      return null;
    }
    
    return cached.data as T;
  }
  
  set(key: string, data: any) {
    this.cache.set(key, { data, timestamp: Date.now() });
  }
  
  clear(key?: string) {
    if (key) {
      this.cache.delete(key);
    } else {
      this.cache.clear();
    }
  }
}

// Usage in service
@Injectable({ providedIn: 'root' })
export class ProductService {
  private cache = inject(CacheService);
  private api = inject(ApiService);
  
  getProducts(): Observable<Product[]> {
    const cached = this.cache.get<Product[]>('products');
    if (cached) {
      return of(cached);
    }
    
    return this.api.get<Product[]>('products').pipe(
      tap(products => this.cache.set('products', products))
    );
  }
}
```

---

## Pattern 8: Loading States

### Unified Loading Pattern

```typescript
// core/models/loading-state.interface.ts
export interface LoadingState<T> {
  loading: boolean;
  data: T | null;
  error: string | null;
}

// Feature service
@Injectable({ providedIn: 'root' })
export class ProductService {
  private state = signal<LoadingState<Product[]>>({
    loading: false,
    data: null,
    error: null
  });
  
  state$ = computed(() => this.state());
  
  loadProducts() {
    this.state.update(s => ({ ...s, loading: true, error: null }));
    
    this.api.get<Product[]>('products').subscribe({
      next: data => this.state.set({ loading: false, data, error: null }),
      error: err => this.state.set({ loading: false, data: null, error: err.message })
    });
  }
}

// Component
@Component({
  template: `
    @if (state().loading) {
      <app-loading-spinner />
    } @else if (state().error) {
      <app-error-message [message]="state().error" />
    } @else if (state().data) {
      @for (product of state().data; track product.id) {
        <app-product-card [product]="product" />
      }
    }
  `
})
export class ProductListComponent {
  private service = inject(ProductService);
  state = this.service.state$;
  
  ngOnInit() {
    this.service.loadProducts();
  }
}
```

---

## Pattern 9: Favor Composition Over Inheritance
=============================================

### Overview
--------

Prefer composing behavior from small, focused units instead of relying on class inheritance.

Inheritance creates tight coupling and rigid structures that do not scale well in large Angular codebases. Composition leads to flexibility, clearer ownership, and easier change.

### Why Composition Is Preferred
----------------------------

Problems with inheritance:
- Tight coupling to base classes
- Fragile base class problem
- Hard to refactor safely
- Single inheritance limitation
- Hidden behavior and side effects

Benefits of composition:
- Explicit dependencies
- Flexible and replaceable behavior
- Easier testing
- Clearer responsibility boundaries
- Works naturally with Angular dependency injection

### Common Composition Examples
---------------------------

1. Service Composition  
   Rule: Services should collaborate, not inherit.

2. Component Composition  
   Rule: Components should never extend other components.

3. Directive-Based Composition  
   Examples:
   - Permissions
   - Tooltips
   - Feature flags
   - Auto-focus
   - Tracking and analytics

4. Behavior Composition with RxJS  
   Examples:
   - View models using combineLatest
   - Derived state using map
   - Side effects isolated with tap

5. Strategy Pattern via Composition  
   Examples:
   - Sorting
   - Validation
   - Pricing rules
   - Feature-specific algorithms

### When Inheritance Is Acceptable (Rare)
------------------------------------

Inheritance is allowed only when:
- Modeling true “is-a” relationships
- Creating abstract, stateless base classes
- Extending framework-provided abstractions

Rules:
- Maximum depth: 1–2 levels
- No shared mutable state
- No business logic in base classes

### Enterprise Rule of Thumb
------------------------

If you are about to use extends, stop and ask:
Can this be done with services, directives, or composition instead?

In Angular, the answer is almost always yes.

---

## Team Structure Patterns

### Pattern 1: Feature Teams
- Each team owns complete features
- Vertical slice (UI + API + DB)
- Autonomous deployment
- Best for: Medium to large teams (10-50+)

### Pattern 2: Layer Teams
- Frontend team, backend team
- Horizontal slice
- Coordinated deployment
- Best for: Small teams (5-10)

### Pattern 3: Component Teams
- Shared component library team
- Feature teams consume components
- Hybrid approach
- Best for: Large organizations (50+)

---

## Summary

Enterprise patterns ensure:
- ✅ Consistent codebase across large teams
- ✅ Predictable structure for new developers
- ✅ Separation of concerns
- ✅ Testable, maintainable code
- ✅ Scalability from day one

**Key Takeaway:** Patterns create consistency. Consistency enables scale.
