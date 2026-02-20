---
name: angular-testing-patterns
description: Use when implementing effective testing strategies and patterns in Angular applications.
---

# Angular Testing Strategies

Comprehensive guide to testing strategies, patterns, and best practices for Angular applications.

## Table of Contents

1. [Testing Pyramid](#testing-pyramid)
2. [Unit Testing Strategies](#unit-testing-strategies)
3. [Integration Testing](#integration-testing)
4. [E2E Testing](#e2e-testing)
5. [Test Organization](#test-organization)
6. [AAA Pattern](#aaa-pattern)
7. [Test Doubles](#test-doubles)
8. [Common Anti-Patterns](#common-anti-patterns)
9. [Performance Optimization](#performance-optimization)
10. [CI/CD Integration](#cicd-integration)

---

## Testing Pyramid

The ideal test distribution for Angular applications:

```
         ╱╲
        ╱ E2E ╲       (5% - Critical user journeys)
       ╱────────╲
      ╱Integration╲   (15% - Component + Service)
     ╱──────────────╲
    ╱   Unit Tests   ╲ (80% - Pure logic, services)
   ╱──────────────────╲
```

### Why This Distribution?

- **Unit Tests (80%)**: Fast, isolated, easy to maintain
- **Integration Tests (15%)**: Test component interactions
- **E2E Tests (5%)**: Slow but verify complete user flows

### Cost vs Coverage

| Test Type | Speed | Cost | Confidence | Maintenance |
|-----------|-------|------|------------|-------------|
| Unit | ⚡⚡⚡ | 💰 | ⭐⭐ | ✅ Easy |
| Integration | ⚡⚡ | 💰💰 | ⭐⭐⭐ | ⚠️ Medium |
| E2E | ⚡ | 💰💰💰 | ⭐⭐⭐⭐ | ❌ Hard |

---

## Unit Testing Strategies

### What to Unit Test

✅ **DO Test**:
- Pure functions and business logic
- Service methods
- Component methods (isolated)
- Pipes and custom validators
- Utility functions
- State management (reducers, selectors)

❌ **DON'T Test**:
- Angular framework internals
- Third-party libraries
- Simple getters/setters
- Generated code

### Component Testing Approaches

#### 1. Shallow Testing (Isolated)

Test component logic without rendering:

```typescript
describe('UserProfileComponent (Shallow)', () => {
  let component: UserProfileComponent;
  let userService: jasmine.SpyObj<UserService>;

  beforeEach(() => {
    userService = jasmine.createSpyObj('UserService', ['getUser', 'updateUser']);
    component = new UserProfileComponent(userService);
  });

  it('should call updateUser with correct data', () => {
    const userData = { name: 'John', email: 'john@example.com' };
    userService.updateUser.and.returnValue(of({ success: true }));

    component.saveProfile(userData);

    expect(userService.updateUser).toHaveBeenCalledWith(userData);
  });
});
```

**Pros**: Fast, focused on logic  
**Cons**: Doesn't test template integration  
**Use for**: Complex business logic, services

#### 2. Deep Testing (TestBed)

Test component with template and dependencies:

```typescript
describe('UserProfileComponent (Deep)', () => {
  let component: UserProfileComponent;
  let fixture: ComponentFixture<UserProfileComponent>;
  let userService: jasmine.SpyObj<UserService>;

  beforeEach(async () => {
    const spy = jasmine.createSpyObj('UserService', ['getUser', 'updateUser']);

    await TestBed.configureTestingModule({
      declarations: [ UserProfileComponent ],
      imports: [ ReactiveFormsModule, HttpClientTestingModule ],
      providers: [
        { provide: UserService, useValue: spy }
      ]
    }).compileComponents();

    userService = TestBed.inject(UserService) as jasmine.SpyObj<UserService>;
    fixture = TestBed.createComponent(UserProfileComponent);
    component = fixture.componentInstance;
  });

  it('should display user name in template', () => {
    const userData = { name: 'John Doe', email: 'john@example.com' };
    userService.getUser.and.returnValue(of(userData));
    
    fixture.detectChanges(); // Trigger change detection

    const compiled = fixture.nativeElement;
    const nameElement = compiled.querySelector('.user-name');
    expect(nameElement.textContent).toContain('John Doe');
  });
});
```

**Pros**: Tests template + logic integration  
**Cons**: Slower, more complex setup  
**Use for**: UI interactions, template binding

### Service Testing Patterns

#### Simple Service (No HTTP)

```typescript
describe('CalculatorService', () => {
  let service: CalculatorService;

  beforeEach(() => {
    service = new CalculatorService();
  });

  it('should add two numbers', () => {
    expect(service.add(2, 3)).toBe(5);
  });

  it('should throw error for division by zero', () => {
    expect(() => service.divide(10, 0)).toThrow();
  });
});
```

#### HTTP Service Testing

```typescript
describe('UserApiService', () => {
  let service: UserApiService;
  let httpMock: HttpTestingController;

  beforeEach(() => {
    TestBed.configureTestingModule({
      imports: [HttpClientTestingModule],
      providers: [UserApiService]
    });

    service = TestBed.inject(UserApiService);
    httpMock = TestBed.inject(HttpTestingController);
  });

  afterEach(() => {
    httpMock.verify(); // Ensure no outstanding requests
  });

  it('should fetch users', () => {
    const mockUsers = [
      { id: 1, name: 'John' },
      { id: 2, name: 'Jane' }
    ];

    service.getUsers().subscribe(users => {
      expect(users).toEqual(mockUsers);
    });

    const req = httpMock.expectOne('/api/users');
    expect(req.request.method).toBe('GET');
    req.flush(mockUsers);
  });

  it('should handle HTTP errors', () => {
    service.getUsers().subscribe({
      next: () => fail('should have failed'),
      error: (error) => {
        expect(error.status).toBe(500);
        expect(error.statusText).toBe('Server Error');
      }
    });

    const req = httpMock.expectOne('/api/users');
    req.flush('Error', { status: 500, statusText: 'Server Error' });
  });
});
```

#### Service with Dependencies

```typescript
describe('AuthService', () => {
  let service: AuthService;
  let http: jasmine.SpyObj<HttpClient>;
  let router: jasmine.SpyObj<Router>;

  beforeEach(() => {
    const httpSpy = jasmine.createSpyObj('HttpClient', ['post', 'get']);
    const routerSpy = jasmine.createSpyObj('Router', ['navigate']);

    TestBed.configureTestingModule({
      providers: [
        AuthService,
        { provide: HttpClient, useValue: httpSpy },
        { provide: Router, useValue: routerSpy }
      ]
    });

    service = TestBed.inject(AuthService);
    http = TestBed.inject(HttpClient) as jasmine.SpyObj<HttpClient>;
    router = TestBed.inject(Router) as jasmine.SpyObj<Router>;
  });

  it('should login and navigate to dashboard', (done) => {
    const mockResponse = { token: 'fake-token' };
    http.post.and.returnValue(of(mockResponse));

    service.login('test@example.com', 'password').subscribe(() => {
      expect(http.post).toHaveBeenCalledWith(
        '/api/auth/login',
        { email: 'test@example.com', password: 'password' }
      );
      expect(router.navigate).toHaveBeenCalledWith(['/dashboard']);
      done();
    });
  });
});
```

### Pipe Testing

```typescript
describe('FilterPipe', () => {
  let pipe: FilterPipe;

  beforeEach(() => {
    pipe = new FilterPipe();
  });

  it('should filter array by search term', () => {
    const items = [
      { name: 'Apple' },
      { name: 'Banana' },
      { name: 'Orange' }
    ];

    const result = pipe.transform(items, 'app', 'name');
    expect(result.length).toBe(1);
    expect(result[0].name).toBe('Apple');
  });

  it('should return empty array when no matches', () => {
    const items = [{ name: 'Apple' }];
    const result = pipe.transform(items, 'xyz', 'name');
    expect(result.length).toBe(0);
  });

  it('should return original array when search is empty', () => {
    const items = [{ name: 'Apple' }, { name: 'Banana' }];
    const result = pipe.transform(items, '', 'name');
    expect(result).toEqual(items);
  });
});
```

### Directive Testing

```typescript
describe('HighlightDirective', () => {
  let fixture: ComponentFixture<TestComponent>;
  let element: DebugElement;

  @Component({
    template: '<div appHighlight="yellow">Test</div>'
  })
  class TestComponent {}

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      declarations: [ HighlightDirective, TestComponent ]
    }).compileComponents();

    fixture = TestBed.createComponent(TestComponent);
    element = fixture.debugElement.query(By.directive(HighlightDirective));
    fixture.detectChanges();
  });

  it('should apply background color', () => {
    const bgColor = element.nativeElement.style.backgroundColor;
    expect(bgColor).toBe('yellow');
  });

  it('should change color on hover', () => {
    element.nativeElement.dispatchEvent(new MouseEvent('mouseenter'));
    fixture.detectChanges();
    expect(element.nativeElement.style.backgroundColor).toBe('orange');
  });
});
```

---

## Integration Testing

### Component + Service Integration

```typescript
describe('ProductListComponent Integration', () => {
  let component: ProductListComponent;
  let fixture: ComponentFixture<ProductListComponent>;
  let productService: ProductService;
  let httpMock: HttpTestingController;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      declarations: [ ProductListComponent ],
      imports: [ HttpClientTestingModule, CommonModule ],
      providers: [ ProductService ]
    }).compileComponents();

    fixture = TestBed.createComponent(ProductListComponent);
    component = fixture.componentInstance;
    productService = TestBed.inject(ProductService);
    httpMock = TestBed.inject(HttpTestingController);
  });

  afterEach(() => {
    httpMock.verify();
  });

  it('should load and display products', () => {
    const mockProducts = [
      { id: 1, name: 'Product 1', price: 100 },
      { id: 2, name: 'Product 2', price: 200 }
    ];

    fixture.detectChanges(); // Trigger ngOnInit

    const req = httpMock.expectOne('/api/products');
    req.flush(mockProducts);
    fixture.detectChanges();

    const compiled = fixture.nativeElement;
    const productElements = compiled.querySelectorAll('.product-item');
    expect(productElements.length).toBe(2);
    expect(productElements[0].textContent).toContain('Product 1');
  });

  it('should handle loading state', () => {
    expect(component.isLoading).toBeFalsy();

    fixture.detectChanges(); // Trigger ngOnInit

    expect(component.isLoading).toBeTruthy();

    const req = httpMock.expectOne('/api/products');
    req.flush([]);

    expect(component.isLoading).toBeFalsy();
  });
});
```

### Router + Guard Integration

```typescript
describe('AuthGuard Integration', () => {
  let guard: AuthGuard;
  let authService: jasmine.SpyObj<AuthService>;
  let router: Router;
  let location: Location;

  beforeEach(async () => {
    const authServiceSpy = jasmine.createSpyObj('AuthService', ['isAuthenticated']);

    await TestBed.configureTestingModule({
      imports: [RouterTestingModule.withRoutes([
        { path: 'dashboard', component: DummyComponent, canActivate: [AuthGuard] },
        { path: 'login', component: DummyComponent }
      ])],
      providers: [
        AuthGuard,
        { provide: AuthService, useValue: authServiceSpy }
      ]
    }).compileComponents();

    guard = TestBed.inject(AuthGuard);
    authService = TestBed.inject(AuthService) as jasmine.SpyObj<AuthService>;
    router = TestBed.inject(Router);
    location = TestBed.inject(Location);
  });

  it('should allow navigation when authenticated', fakeAsync(() => {
    authService.isAuthenticated.and.returnValue(true);

    router.navigate(['/dashboard']);
    tick();

    expect(location.path()).toBe('/dashboard');
  }));

  it('should redirect to login when not authenticated', fakeAsync(() => {
    authService.isAuthenticated.and.returnValue(false);

    router.navigate(['/dashboard']);
    tick();

    expect(location.path()).toBe('/login');
  }));
});
```

---

## E2E Testing

### Cypress E2E Strategy

```typescript
// cypress/e2e/user-journey.cy.ts
describe('Complete User Journey', () => {
  beforeEach(() => {
    // Reset database state
    cy.task('db:seed');
    cy.visit('/');
  });

  it('should complete purchase flow', () => {
    // Login
    cy.getBySel('login-button').click();
    cy.getBySel('email-input').type('test@example.com');
    cy.getBySel('password-input').type('password123');
    cy.getBySel('submit-button').click();

    // Browse products
    cy.url().should('include', '/products');
    cy.getBySel('product-card').first().click();

    // Add to cart
    cy.getBySel('add-to-cart-button').click();
    cy.getBySel('cart-badge').should('contain', '1');

    // Checkout
    cy.getBySel('cart-icon').click();
    cy.getBySel('checkout-button').click();

    // Fill shipping info
    cy.getBySel('address-input').type('123 Main St');
    cy.getBySel('city-input').type('New York');
    cy.getBySel('zipcode-input').type('10001');

    // Complete purchase
    cy.getBySel('complete-order-button').click();
    cy.url().should('include', '/order-confirmation');
    cy.getBySel('success-message').should('be.visible');
  });
});
```

### Playwright E2E Strategy

```typescript
// e2e/user-journey.spec.ts
import { test, expect } from '@playwright/test';

test.describe('Complete User Journey', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
  });

  test('should complete purchase flow', async ({ page }) => {
    // Login
    await page.click('[data-testid="login-button"]');
    await page.fill('[data-testid="email-input"]', 'test@example.com');
    await page.fill('[data-testid="password-input"]', 'password123');
    await page.click('[data-testid="submit-button"]');

    // Wait for navigation
    await page.waitForURL('**/products');

    // Browse products
    await page.click('[data-testid="product-card"] >> nth=0');

    // Add to cart
    await page.click('[data-testid="add-to-cart-button"]');
    await expect(page.locator('[data-testid="cart-badge"]')).toHaveText('1');

    // Checkout
    await page.click('[data-testid="cart-icon"]');
    await page.click('[data-testid="checkout-button"]');

    // Fill shipping info
    await page.fill('[data-testid="address-input"]', '123 Main St');
    await page.fill('[data-testid="city-input"]', 'New York');
    await page.fill('[data-testid="zipcode-input"]', '10001');

    // Complete purchase
    await page.click('[data-testid="complete-order-button"]');
    await expect(page).toHaveURL(/.*order-confirmation/);
    await expect(page.locator('[data-testid="success-message"]')).toBeVisible();
  });
});
```

---

## Test Organization

### File Structure

```
src/app/
├── components/
│   ├── user-profile/
│   │   ├── user-profile.component.ts
│   │   ├── user-profile.component.spec.ts
│   │   ├── user-profile.component.html
│   │   └── user-profile.component.scss
│   └── shared/
│       └── button/
│           ├── button.component.ts
│           └── button.component.spec.ts
├── services/
│   ├── auth.service.ts
│   ├── auth.service.spec.ts
│   ├── user.service.ts
│   └── user.service.spec.ts
├── guards/
│   ├── auth.guard.ts
│   └── auth.guard.spec.ts
├── pipes/
│   ├── filter.pipe.ts
│   └── filter.pipe.spec.ts
└── testing/
    ├── mocks/
    │   ├── mock-auth.service.ts
    │   └── mock-user.service.ts
    ├── fixtures/
    │   ├── user.fixture.ts
    │   └── product.fixture.ts
    └── helpers/
        ├── test-utils.ts
        └── custom-matchers.ts
```

### Test Helper Functions

```typescript
// src/app/testing/helpers/test-utils.ts

/**
 * Create a mock Observable that emits immediately
 */
export function createMockObservable<T>(data: T): Observable<T> {
  return of(data);
}

/**
 * Create a mock Observable that throws an error
 */
export function createMockError(error: any): Observable<never> {
  return throwError(() => error);
}

/**
 * Click a button and wait for async operations
 */
export async function clickButton(
  fixture: ComponentFixture<any>,
  selector: string
): Promise<void> {
  const button = fixture.nativeElement.querySelector(selector);
  button.click();
  fixture.detectChanges();
  await fixture.whenStable();
}

/**
 * Set form values
 */
export function setFormValues(
  form: FormGroup,
  values: { [key: string]: any }
): void {
  Object.keys(values).forEach(key => {
    const control = form.get(key);
    if (control) {
      control.setValue(values[key]);
      control.markAsTouched();
    }
  });
}

/**
 * Create spy object with typed methods
 */
export function createSpyObj<T>(
  baseName: string,
  methodNames: (keyof T)[]
): jasmine.SpyObj<T> {
  return jasmine.createSpyObj(baseName, methodNames as string[]);
}
```

### Test Fixtures

```typescript
// src/app/testing/fixtures/user.fixture.ts

export class UserFixtures {
  static readonly VALID_USER = {
    id: 1,
    email: 'test@example.com',
    name: 'Test User',
    role: 'user'
  };

  static readonly ADMIN_USER = {
    id: 2,
    email: 'admin@example.com',
    name: 'Admin User',
    role: 'admin'
  };

  static readonly USER_LIST = [
    UserFixtures.VALID_USER,
    UserFixtures.ADMIN_USER,
    {
      id: 3,
      email: 'user3@example.com',
      name: 'User Three',
      role: 'user'
    }
  ];

  static createUser(overrides: Partial<User> = {}): User {
    return {
      ...UserFixtures.VALID_USER,
      ...overrides
    };
  }
}
```

---

## AAA Pattern

### Arrange-Act-Assert Structure

```typescript
describe('ShoppingCartService', () => {
  it('should add item to cart', () => {
    // ===== ARRANGE =====
    // Set up test data and dependencies
    const service = new ShoppingCartService();
    const product = {
      id: 1,
      name: 'Test Product',
      price: 99.99
    };

    // ===== ACT =====
    // Execute the behavior being tested
    service.addToCart(product);

    // ===== ASSERT =====
    // Verify the expected outcome
    expect(service.getCartItems().length).toBe(1);
    expect(service.getCartItems()[0]).toEqual(product);
    expect(service.getTotal()).toBe(99.99);
  });
});
```

### Why AAA Pattern?

✅ **Readability**: Clear test structure  
✅ **Maintainability**: Easy to update  
✅ **Debugging**: Quickly identify failures  
✅ **Consistency**: Uniform test style

### Common Variations

```typescript
// Given-When-Then (BDD style)
it('should add item to cart', () => {
  // GIVEN: A shopping cart and a product
  const service = new ShoppingCartService();
  const product = { id: 1, name: 'Product', price: 99.99 };

  // WHEN: Adding the product to cart
  service.addToCart(product);

  // THEN: Cart should contain the product
  expect(service.getCartItems()).toContain(product);
});
```

---

## Test Doubles

### Types of Test Doubles

1. **Dummy**: Passed but never used
2. **Stub**: Provides preset responses
3. **Spy**: Records how it was called
4. **Mock**: Pre-programmed with expectations
5. **Fake**: Working implementation (simplified)

### Jasmine Spies

```typescript
// Creating spies
const spy = jasmine.createSpy('myFunction');
const spyObj = jasmine.createSpyObj('MyService', ['method1', 'method2']);

// Spy on existing method
spyOn(service, 'getData').and.returnValue(of(mockData));

// Spy configurations
spy.and.returnValue(42);
spy.and.returnValues(1, 2, 3);
spy.and.callFake(() => 'custom logic');
spy.and.callThrough(); // Call actual method
spy.and.throwError('error message');

// Assertions
expect(spy).toHaveBeenCalled();
expect(spy).toHaveBeenCalledTimes(2);
expect(spy).toHaveBeenCalledWith('arg1', 'arg2');
expect(spy).toHaveBeenCalledBefore(anotherSpy);
```

### Mock HTTP Responses

```typescript
it('should handle successful API call', () => {
  service.getUsers().subscribe(users => {
    expect(users.length).toBe(2);
  });

  const req = httpMock.expectOne('/api/users');
  expect(req.request.method).toBe('GET');
  
  req.flush([
    { id: 1, name: 'User 1' },
    { id: 2, name: 'User 2' }
  ]);
});

it('should handle API errors', () => {
  service.getUsers().subscribe({
    error: (error) => {
      expect(error.status).toBe(404);
    }
  });

  const req = httpMock.expectOne('/api/users');
  req.flush('Not Found', { status: 404, statusText: 'Not Found' });
});
```

---

## Common Anti-Patterns

### ❌ Testing Implementation Details

```typescript
// BAD: Testing private methods
it('should call private method', () => {
  spyOn(component as any, 'privateMethod');
  component.publicMethod();
  expect((component as any).privateMethod).toHaveBeenCalled();
});

// GOOD: Test public behavior
it('should update user list', () => {
  component.refreshUsers();
  expect(component.users.length).toBeGreaterThan(0);
});
```

### ❌ Flaky Tests

```typescript
// BAD: Time-dependent tests
it('should update after delay', (done) => {
  service.delayedUpdate();
  setTimeout(() => {
    expect(service.value).toBe(42);
    done();
  }, 100); // Magic number!
});

// GOOD: Use fakeAsync
it('should update after delay', fakeAsync(() => {
  service.delayedUpdate();
  tick(1000);
  expect(service.value).toBe(42);
}));
```

### ❌ Test Interdependence

```typescript
// BAD: Tests depend on each other
describe('UserService', () => {
  let userId: number;

  it('should create user', () => {
    userId = service.createUser({ name: 'Test' });
    expect(userId).toBeDefined();
  });

  it('should get user', () => {
    const user = service.getUser(userId); // Depends on previous test!
    expect(user.name).toBe('Test');
  });
});

// GOOD: Independent tests
describe('UserService', () => {
  beforeEach(() => {
    // Reset state before each test
    service.clear();
  });

  it('should create user', () => {
    const userId = service.createUser({ name: 'Test' });
    expect(userId).toBeDefined();
  });

  it('should get user', () => {
    const userId = service.createUser({ name: 'Test' });
    const user = service.getUser(userId);
    expect(user.name).toBe('Test');
  });
});
```

### ❌ Over-Mocking

```typescript
// BAD: Mocking everything
it('should calculate total', () => {
  spyOn(Math, 'round').and.returnValue(100);
  spyOn(Math, 'floor').and.returnValue(99);
  // Too many mocks!
});

// GOOD: Only mock external dependencies
it('should calculate total', () => {
  const cart = new ShoppingCart();
  cart.addItem({ price: 10, quantity: 3 });
  expect(cart.getTotal()).toBe(30);
});
```

---

## Performance Optimization

### Run Tests in Parallel

```json
// karma.conf.js
module.exports = function(config) {
  config.set({
    browsers: ['ChromeHeadless'],
    concurrency: 5, // Run 5 instances in parallel
    browserNoActivityTimeout: 60000
  });
};
```

### Use Shallow Testing When Possible

```typescript
// Fast: Shallow test
describe('Component (Shallow)', () => {
  it('should calculate total', () => {
    const component = new PriceCalculatorComponent();
    component.price = 100;
    component.quantity = 2;
    expect(component.total).toBe(200);
  });
});

// Slow: Full TestBed
describe('Component (Deep)', () => {
  let fixture: ComponentFixture<PriceCalculatorComponent>;
  
  beforeEach(async () => {
    await TestBed.configureTestingModule({
      declarations: [ PriceCalculatorComponent ],
      imports: [ CommonModule, FormsModule ]
    }).compileComponents();
    
    fixture = TestBed.createComponent(PriceCalculatorComponent);
  });

  it('should calculate total', () => {
    // Much slower setup
  });
});
```

### Skip Heavy Tests in Watch Mode

```typescript
// Use fdescribe/fit for focused testing during development
fdescribe('UserComponent', () => {
  fit('should create', () => {
    expect(component).toBeTruthy();
  });
});

// Or use xdescribe/xit to skip tests
xdescribe('SlowE2ETests', () => {
  // These tests won't run
});
```

---

## CI/CD Integration

### GitHub Actions

```yaml
name: Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v3
      
      - uses: actions/setup-node@v3
        with:
          node-version: '20'
          cache: 'npm'
      
      - name: Install dependencies
        run: npm ci
      
      - name: Run unit tests
        run: npm run test:ci
      
      - name: Generate coverage
        run: npm run test:coverage
      
      - name: Upload coverage to Codecov
        uses: codecov/codecov-action@v3
        with:
          files: ./coverage/lcov.info
      
      - name: Run E2E tests
        run: npm run e2e:ci
      
      - name: Upload test results
        if: always()
        uses: actions/upload-artifact@v3
        with:
          name: test-results
          path: |
            coverage/
            cypress/screenshots/
            cypress/videos/
```

### Package.json Scripts

```json
{
  "scripts": {
    "test": "ng test",
    "test:ci": "ng test --watch=false --browsers=ChromeHeadless --code-coverage",
    "test:coverage": "ng test --code-coverage --watch=false",
    "test:watch": "ng test --watch=true",
    "e2e": "cypress open",
    "e2e:ci": "cypress run --browser chrome"
  }
}
```

---

## Best Practices Summary

✅ **DO**:
- Follow AAA pattern
- Test behavior, not implementation
- Keep tests isolated and independent
- Use descriptive test names
- Mock external dependencies
- Aim for 80% code coverage
- Run tests before committing
- Use CI/CD for automated testing

❌ **DON'T**:
- Test framework internals
- Create dependent tests
- Use magic numbers or strings
- Test private methods
- Ignore flaky tests
- Skip edge cases
- Over-mock everything

---

## Quick Reference

### Test Types

| Type | Purpose | Speed | Coverage |
|------|---------|-------|----------|
| Unit | Test isolated logic | ⚡⚡⚡ | 80% |
| Integration | Test component + service | ⚡⚡ | 15% |
| E2E | Test user workflows | ⚡ | 5% |

### Common Matchers

```typescript
expect(value).toBe(42);
expect(value).toEqual({ id: 1 });
expect(value).toBeTruthy();
expect(value).toBeFalsy();
expect(array).toContain(item);
expect(fn).toThrow();
expect(spy).toHaveBeenCalled();
expect(spy).toHaveBeenCalledWith(arg);
```

### Async Testing

```typescript
// Using done()
it('async test', (done) => {
  service.getData().subscribe(data => {
    expect(data).toBeTruthy();
    done();
  });
});

// Using fakeAsync
it('async test', fakeAsync(() => {
  service.delayedAction();
  tick(1000);
  expect(service.value).toBe(42);
}));

// Using async/await
it('async test', async () => {
  const data = await service.getData().toPromise();
  expect(data).toBeTruthy();
});
```

---

*Master these strategies to build bulletproof Angular applications! 🛡️*