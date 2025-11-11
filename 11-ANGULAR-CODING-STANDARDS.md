# 11. Angular Coding Standards (Jupiter ec-std-01)

## Overview

This document establishes coding standards for Angular applications in the OElite platform, specifically for the production template `jupiter/ec-std-01`. These standards ensure consistency, maintainability, and enterprise-grade quality across all Angular eCommerce implementations.

**Technology Stack**: Angular 12+, TypeScript, Bootstrap 4, NgBootstrap, SSR, i18n

## 🎯 **Critical UI Implementation Practices**

### **Mandatory Requirements for All Angular Applications**

The following practices are **MANDATORY** for all OElite Angular applications to ensure professional, maintainable, and user-friendly interfaces.

### 1. **Responsive Design with Mobile-First Approach** 🚨

#### **MANDATORY: Mobile-First Development**

All components MUST be designed mobile-first and scale up to larger screens:

```scss
// ✅ CORRECT - Mobile-first approach using Bootstrap breakpoints
.product-card {
  // Mobile styles (default)
  padding: 0.5rem;
  font-size: 0.875rem;

  // Tablet and up
  @include media-breakpoint-up(md) {
    padding: 1rem;
    font-size: 1rem;
  }

  // Desktop and up
  @include media-breakpoint-up(lg) {
    padding: 1.5rem;
    font-size: 1.125rem;
  }

  // Large screens
  @include media-breakpoint-up(xl) {
    padding: 2rem;
    font-size: 1.25rem;
  }
}

// ❌ FORBIDDEN - Desktop-first approach
.product-card {
  padding: 2rem; // Desktop style as default

  @media (max-width: 768px) {
    padding: 0.5rem; // Mobile as afterthought
  }
}
```

#### **MANDATORY: Bootstrap Grid System**

Use Bootstrap's responsive grid system properly:

```html
<!-- ✅ CORRECT - Responsive layout with proper breakpoints -->
<div class="container-fluid">
  <div class="row">
    <!-- Stack on mobile, 2 columns on tablet, 3 on desktop, 4 on large screens -->
    <div class="col-12 col-md-6 col-lg-4 col-xl-3" *ngFor="let product of products">
      <oes-product-card [product]="product"></oes-product-card>
    </div>
  </div>
</div>

<!-- ❌ FORBIDDEN - Fixed columns that don't adapt -->
<div class="col-4" *ngFor="let product of products">
  <oes-product-card [product]="product"></oes-product-card>
</div>
```

#### **Angular CDK Layout for Responsive Logic**

```typescript
// ✅ CORRECT - Using Angular CDK for responsive behavior
import { BreakpointObserver, Breakpoints } from '@angular/cdk/layout';

@Component({
  selector: 'oes-product-grid',
  template: `
    <div class="product-grid" [class.mobile-view]="isMobile$ | async">
      <oes-product-card
        *ngFor="let product of products"
        [product]="product"
        [layout]="(isMobile$ | async) ? 'compact' : 'full'">
      </oes-product-card>
    </div>
  `
})
export class ProductGridComponent {
  isMobile$ = this.breakpointObserver.observe([
    Breakpoints.Handset
  ]).pipe(map(result => result.matches));

  constructor(private breakpointObserver: BreakpointObserver) {}
}
```

### 2. **Mobile-Specific Component Strategy** 📱

#### **When to Create Mobile-Specific Components**

Create dedicated mobile components when:
- Desktop UI cannot be reasonably adapted for mobile
- Mobile requires fundamentally different interaction patterns
- Performance optimization is needed for mobile devices

```typescript
// ✅ CORRECT - Mobile-specific navigation
@Component({
  selector: 'oes-mobile-navigation',
  template: `
    <div class="mobile-nav d-md-none">
      <!-- Touch-optimized hamburger menu -->
      <button class="nav-toggle" (click)="toggleMenu()"
              [attr.aria-expanded]="isMenuOpen">
        <span class="hamburger-line"></span>
        <span class="hamburger-line"></span>
        <span class="hamburger-line"></span>
      </button>

      <!-- Full-screen mobile menu -->
      <div class="mobile-menu" [class.open]="isMenuOpen">
        <nav class="mobile-nav-links">
          <a *ngFor="let item of navigationItems"
             [routerLink]="item.link"
             class="mobile-nav-item"
             (click)="closeMenu()">
            {{ item.label }}
          </a>
        </nav>
      </div>
    </div>
  `,
  styleUrls: ['./mobile-navigation.component.scss']
})
export class MobileNavigationComponent {
  isMenuOpen = false;

  toggleMenu(): void {
    this.isMenuOpen = !this.isMenuOpen;
  }

  closeMenu(): void {
    this.isMenuOpen = false;
  }
}

// ✅ CORRECT - Desktop navigation (separate component)
@Component({
  selector: 'oes-desktop-navigation',
  template: `
    <nav class="desktop-nav d-none d-md-block">
      <ul class="nav-menu">
        <li *ngFor="let item of navigationItems" class="nav-item">
          <a [routerLink]="item.link" class="nav-link">{{ item.label }}</a>
        </li>
      </ul>
    </nav>
  `
})
export class DesktopNavigationComponent {}
```

#### **Component Substitution Pattern**

```html
<!-- ✅ CORRECT - Conditional component loading -->
<oes-mobile-navigation class="d-md-none"></oes-mobile-navigation>
<oes-desktop-navigation class="d-none d-md-block"></oes-desktop-navigation>

<!-- ✅ CORRECT - Using Angular CDK for dynamic components -->
<ng-container *ngIf="isMobile$ | async; else desktopTable">
  <oes-mobile-product-cards [products]="products"></oes-mobile-product-cards>
</ng-container>
<ng-template #desktopTable>
  <oes-product-table [products]="products"></oes-product-table>
</ng-template>
```

### 3. **Architectural Modularity and Reusability** 🏗️

#### **MANDATORY: Reusable Component Design**

Design components to be modular and reusable across different contexts:

```typescript
// ✅ CORRECT - Generic, reusable dialog component
@Component({
  selector: 'oes-dialog',
  template: `
    <div class="dialog-overlay" *ngIf="isOpen" (click)="onOverlayClick($event)">
      <div class="dialog-container" [class]="dialogSize">
        <header class="dialog-header" *ngIf="title || hasHeaderContent">
          <h2 class="dialog-title" *ngIf="title">{{ title }}</h2>
          <ng-content select="[slot=header]"></ng-content>
          <button class="dialog-close" (click)="close()" *ngIf="showCloseButton">
            <i class="fas fa-times"></i>
          </button>
        </header>

        <main class="dialog-body">
          <ng-content></ng-content>
        </main>

        <footer class="dialog-footer" *ngIf="hasFooterContent">
          <ng-content select="[slot=footer]"></ng-content>
        </footer>
      </div>
    </div>
  `
})
export class DialogComponent {
  @Input() isOpen = false;
  @Input() title?: string;
  @Input() dialogSize: 'sm' | 'md' | 'lg' | 'xl' = 'md';
  @Input() showCloseButton = true;
  @Input() closeOnOverlayClick = true;

  @Output() opened = new EventEmitter<void>();
  @Output() closed = new EventEmitter<void>();

  @ContentChild('header') hasHeaderContent?: ElementRef;
  @ContentChild('footer') hasFooterContent?: ElementRef;

  close(): void {
    this.isOpen = false;
    this.closed.emit();
  }
}

// ✅ Usage in different contexts
// Product details modal
// <oes-dialog [(isOpen)]="showProductDetails" title="Product Details" dialogSize="lg">
//   <oes-product-details [product]="selectedProduct"></oes-product-details>
//   <div slot="footer">
//     <button class="btn btn-primary" (click)="addToCart()">Add to Cart</button>
//   </div>
// </oes-dialog>

// Confirmation dialog
// <oes-dialog [(isOpen)]="showConfirmation" title="Confirm Action" dialogSize="sm">
//   <p>Are you sure you want to delete this item?</p>
//   <div slot="footer">
//     <button class="btn btn-secondary" (click)="cancel()">Cancel</button>
//     <button class="btn btn-danger" (click)="confirm()">Delete</button>
//   </div>
// </oes-dialog>
```

#### **Generic TreeView Component**

```typescript
// ✅ CORRECT - Generic, reusable tree component
export interface TreeNode<T = any> {
  id: string;
  label: string;
  data?: T;
  children?: TreeNode<T>[];
  expanded?: boolean;
  selected?: boolean;
  icon?: string;
}

@Component({
  selector: 'oes-tree-view',
  template: `
    <div class="tree-view">
      <oes-tree-node
        *ngFor="let node of nodes; trackBy: trackByFn"
        [node]="node"
        [level]="0"
        (nodeSelected)="onNodeSelected($event)"
        (nodeToggled)="onNodeToggled($event)">
      </oes-tree-node>
    </div>
  `
})
export class TreeViewComponent<T = any> {
  @Input() nodes: TreeNode<T>[] = [];
  @Input() multiSelect = false;
  @Output() nodeSelected = new EventEmitter<TreeNode<T>>();
  @Output() nodeToggled = new EventEmitter<TreeNode<T>>();

  trackByFn(index: number, node: TreeNode<T>): string {
    return node.id;
  }
}

// ✅ Usage for different business domains

// Category navigation
// <oes-tree-view
//   [nodes]="categoryTree"
//   (nodeSelected)="selectCategory($event)">
// </oes-tree-view>

// Organization structure
// <oes-tree-view
//   [nodes]="organizationTree"
//   [multiSelect]="true"
//   (nodeSelected)="selectDepartment($event)">
// </oes-tree-view>
```

### 4. **Object-Oriented Design - No Hard Coding** 🎯

#### **Configuration Classes**

```typescript
// ✅ CORRECT - Centralized configuration
export class AppConfig {
  static readonly API_ENDPOINTS = {
    PRODUCTS: '/api/products',
    CUSTOMERS: '/api/customers',
    ORDERS: '/api/orders'
  } as const;

  static readonly UI_CONSTANTS = {
    PAGINATION_SIZE: 20,
    MOBILE_BREAKPOINT: 768,
    TOAST_DURATION: 3000
  } as const;

  static readonly ROUTES = {
    HOME: '/',
    PRODUCTS: '/products',
    PRODUCT_DETAIL: '/products/:id',
    CART: '/cart',
    CHECKOUT: '/checkout'
  } as const;
}

// ❌ FORBIDDEN - Hard-coded values in components
@Component({
  template: `
    <div *ngIf="windowWidth <= 768"> <!-- FORBIDDEN! -->
      <!-- Mobile layout -->
    </div>
  `
})
export class BadComponent {
  getData() {
    return this.http.get('/api/products'); // FORBIDDEN!
  }
}
```

#### **Type-Safe Constants and Enums**

```typescript
// ✅ CORRECT - Type-safe enums for UI states
export enum ProductStatus {
  ACTIVE = 'active',
  INACTIVE = 'inactive',
  OUT_OF_STOCK = 'out_of_stock',
  DISCONTINUED = 'discontinued'
}

export enum CartActionType {
  ADD_ITEM = 'ADD_ITEM',
  REMOVE_ITEM = 'REMOVE_ITEM',
  UPDATE_QUANTITY = 'UPDATE_QUANTITY',
  CLEAR_CART = 'CLEAR_CART'
}

// ✅ CORRECT - Configuration service
@Injectable({ providedIn: 'root' })
export class ConfigurationService {
  private readonly config = {
    api: {
      baseUrl: environment.apiUrl,
      timeout: environment.apiTimeout,
      retryAttempts: 3
    },
    ui: {
      itemsPerPage: 20,
      mobileBreakpoint: 768,
      animationDuration: 300
    },
    features: {
      enableWishlist: environment.features.wishlist,
      enableComparision: environment.features.comparison,
      enableReviews: environment.features.reviews
    }
  };

  getApiConfig() { return this.config.api; }
  getUIConfig() { return this.config.ui; }
  getFeatureConfig() { return this.config.features; }
}
```

#### **Translation Keys Management**

```typescript
// ✅ CORRECT - Centralized translation keys
export const TRANSLATION_KEYS = {
  COMMON: {
    SAVE: 'common.save',
    CANCEL: 'common.cancel',
    DELETE: 'common.delete',
    CONFIRM: 'common.confirm'
  },
  PRODUCTS: {
    TITLE: 'products.title',
    ADD_TO_CART: 'products.addToCart',
    OUT_OF_STOCK: 'products.outOfStock'
  },
  ERRORS: {
    NETWORK: 'errors.network',
    VALIDATION: 'errors.validation',
    NOT_FOUND: 'errors.notFound'
  }
} as const;

// ✅ Usage in components
@Component({
  template: `
    <button class="btn btn-primary" (click)="addToCart()">
      {{ KEYS.PRODUCTS.ADD_TO_CART | translate }}
    </button>
  `
})
export class ProductComponent {
  readonly KEYS = TRANSLATION_KEYS;
}
```

### 5. **Centralized Non-UI Code Organization** 📚

#### **Business Domain Library Structure**

```
src/lib/
├── core/                    # Core utilities
│   ├── api/                # API utilities
│   ├── auth/               # Authentication logic
│   ├── cache/              # Caching utilities
│   ├── error/              # Error handling
│   ├── logging/            # Logging utilities
│   └── storage/            # Storage abstractions
├── domains/                # Business domains
│   ├── products/
│   │   ├── models/         # Product interfaces/types
│   │   ├── services/       # Product API services
│   │   ├── utils/          # Product-specific utilities
│   │   ├── validators/     # Product validation logic
│   │   └── index.ts        # Public API
│   ├── customers/
│   │   ├── models/
│   │   ├── services/
│   │   ├── utils/
│   │   └── index.ts
│   ├── orders/
│   │   ├── models/
│   │   ├── services/
│   │   ├── utils/
│   │   └── index.ts
│   └── payments/
│       ├── models/
│       ├── services/
│       ├── utils/
│       └── index.ts
└── shared/                 # Shared utilities
    ├── types/              # Common types
    ├── constants/          # Application constants
    ├── utils/              # General utilities
    └── validators/         # Common validators
```

#### **Domain-Specific Services**

```typescript
// ✅ src/lib/domains/products/services/product.service.ts
export class ProductService {
  constructor(private http: HttpClient) {}

  getProducts(params: ProductQuery): Observable<Product[]> {
    return this.http.get<Product[]>(AppConfig.API_ENDPOINTS.PRODUCTS, { params });
  }

  getProductById(id: string): Observable<Product> {
    return this.http.get<Product>(`${AppConfig.API_ENDPOINTS.PRODUCTS}/${id}`);
  }

  searchProducts(query: string): Observable<Product[]> {
    return this.http.get<Product[]>(`${AppConfig.API_ENDPOINTS.PRODUCTS}/search`, {
      params: { q: query }
    });
  }
}

// ✅ src/lib/domains/products/utils/product.utils.ts
export class ProductUtils {
  static formatPrice(price: number, currency = 'USD'): string {
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency
    }).format(price);
  }

  static calculateDiscount(originalPrice: number, salePrice: number): number {
    return Math.round(((originalPrice - salePrice) / originalPrice) * 100);
  }

  static isInStock(product: Product): boolean {
    return product.status === ProductStatus.ACTIVE && product.stockQuantity > 0;
  }
}

// ✅ src/lib/domains/products/index.ts - Public API
export * from './models/product.interface';
export * from './models/product-query.interface';
export * from './services/product.service';
export * from './utils/product.utils';
export * from './validators/product.validators';
```

#### **NPM Package Preparation**

```typescript
// ✅ Prepare for potential NPM package extraction
// package.json structure for domain packages
{
  "name": "@oelite/products-lib",
  "version": "1.0.0",
  "main": "dist/index.js",
  "types": "dist/index.d.ts",
  "exports": {
    ".": "./dist/index.js",
    "./services": "./dist/services/index.js",
    "./utils": "./dist/utils/index.js",
    "./models": "./dist/models/index.js"
  }
}

// ✅ Clean public API
// src/lib/domains/products/index.ts
export { ProductService } from './services/product.service';
export { ProductUtils } from './utils/product.utils';
export { ProductValidators } from './validators/product.validators';
export type {
  Product,
  ProductQuery,
  ProductStatus,
  ProductCategory
} from './models';
```

### 6. **Framework-Specific Best Practices** ⚡

#### **Angular Performance Optimization**

```typescript
// ✅ CORRECT - OnPush change detection
@Component({
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <div *ngFor="let item of items; trackBy: trackByFn">
      {{ item.name }}
    </div>
  `
})
export class OptimizedListComponent {
  @Input() items: Product[] = [];

  constructor(private cdr: ChangeDetectorRef) {}

  trackByFn(index: number, item: Product): string {
    return item.id; // Use unique identifier for tracking
  }
}

// ✅ CORRECT - Async pipe for observables
@Component({
  template: `
    <div *ngIf="products$ | async as products">
      <oes-product-card
        *ngFor="let product of products; trackBy: trackByFn"
        [product]="product">
      </oes-product-card>
    </div>
  `
})
export class ProductListComponent {
  products$ = this.productService.getProducts();

  trackByFn = (index: number, product: Product) => product.id;
}
```

#### **Reactive Forms Best Practices**

```typescript
// ✅ CORRECT - Reactive forms with validation
@Component({
  template: `
    <form [formGroup]="productForm" (ngSubmit)="onSubmit()">
      <div class="form-group">
        <label for="name">Product Name</label>
        <input
          id="name"
          type="text"
          class="form-control"
          [class.is-invalid]="isFieldInvalid('name')"
          formControlName="name"
          placeholder="Enter product name">
        <div class="invalid-feedback" *ngIf="isFieldInvalid('name')">
          {{ getFieldError('name') }}
        </div>
      </div>
    </form>
  `
})
export class ProductFormComponent {
  productForm = this.fb.group({
    name: ['', [Validators.required, Validators.minLength(2)]],
    price: [0, [Validators.required, Validators.min(0.01)]],
    description: ['', [Validators.maxLength(500)]]
  });

  constructor(private fb: FormBuilder) {}

  isFieldInvalid(fieldName: string): boolean {
    const field = this.productForm.get(fieldName);
    return !!(field?.invalid && (field?.dirty || field?.touched));
  }

  getFieldError(fieldName: string): string {
    const field = this.productForm.get(fieldName);
    if (field?.errors) {
      if (field.errors['required']) return `${fieldName} is required`;
      if (field.errors['minlength']) return `${fieldName} is too short`;
      if (field.errors['min']) return `${fieldName} must be greater than 0`;
    }
    return '';
  }
}
```

#### **State Management Best Practices**

```typescript
// ✅ CORRECT - Using NgRx for complex state
@Injectable()
export class ProductEffects {
  loadProducts$ = createEffect(() =>
    this.actions$.pipe(
      ofType(ProductActions.loadProducts),
      switchMap(action =>
        this.productService.getProducts(action.query).pipe(
          map(products => ProductActions.loadProductsSuccess({ products })),
          catchError(error => of(ProductActions.loadProductsFailure({ error })))
        )
      )
    )
  );

  constructor(
    private actions$: Actions,
    private productService: ProductService
  ) {}
}

// ✅ CORRECT - Simple state with services for smaller apps
@Injectable({ providedIn: 'root' })
export class CartStateService {
  private cartSubject = new BehaviorSubject<CartItem[]>([]);
  public cart$ = this.cartSubject.asObservable();

  addItem(product: Product, quantity = 1): void {
    const currentCart = this.cartSubject.value;
    const existingItem = currentCart.find(item => item.product.id === product.id);

    if (existingItem) {
      existingItem.quantity += quantity;
    } else {
      currentCart.push({ product, quantity });
    }

    this.cartSubject.next([...currentCart]);
  }

  removeItem(productId: string): void {
    const currentCart = this.cartSubject.value;
    const updatedCart = currentCart.filter(item => item.product.id !== productId);
    this.cartSubject.next(updatedCart);
  }
}
```

## Project Architecture Standards

### 1. **Directory Structure** (Mandatory)

Follow the established OElite Angular architecture:

```
src/app/
├── account/           # User account management
├── i18n/             # Internationalization files
├── layout/           # Site layout components (header, footer, nav)
├── modules/          # Feature modules
├── pages/            # Static/content pages
├── services/         # Global services
├── shared/           # Shared components, pipes, directives
├── shop/             # eCommerce functionality
├── ui-blocks/        # Reusable UI components
├── app.component.*   # Root component
├── app.module.ts     # Root module
├── oes.module.ts     # OES feature module
└── oes.routing.ts    # Application routing
```

### 2. **Module Organization** ✅

Organize features into logical modules with clear boundaries:

```typescript
// ✅ CORRECT - Feature module with clear responsibility
@NgModule({
  declarations: [
    ShopComponent,
    ProductListComponent,
    ProductDetailComponent,
    CartComponent
  ],
  imports: [
    CommonModule,
    ShopRoutingModule,
    SharedModule
  ],
  providers: [
    ProductService,
    CartService
  ]
})
export class ShopModule { }
```

### 3. **Forbidden Patterns** ❌

```typescript
// ❌ FORBIDDEN - Everything in a single module
@NgModule({
  declarations: [
    // 50+ components in one module
  ]
})

// ❌ FORBIDDEN - Deep nesting without modules
src/app/shop/products/categories/subcategories/items/

// ❌ FORBIDDEN - Services in component folders
src/app/shop/product/product.service.ts  // Should be in services/
```

## Component Standards

### 1. **Component Architecture** ✅

Follow Angular best practices with OElite patterns:

```typescript
// ✅ CORRECT - Component with proper lifecycle and DI
@Component({
  selector: 'oes-product-card',
  templateUrl: './product-card.component.html',
  styleUrls: ['./product-card.component.scss'],
  changeDetection: ChangeDetectionStrategy.OnPush
})
export class ProductCardComponent implements OnInit, OnDestroy {
  @Input() product: Product;
  @Input() showQuickView: boolean = true;
  @Output() addToCart = new EventEmitter<Product>();

  private alive = true;

  constructor(
    private productService: ProductService,
    private cartService: CartService,
    private cdr: ChangeDetectorRef
  ) {}

  ngOnInit(): void {
    this.productService.productUpdated$
      .pipe(takeWhile(() => this.alive))
      .subscribe(updatedProduct => {
        if (updatedProduct.id === this.product.id) {
          this.product = updatedProduct;
          this.cdr.markForCheck();
        }
      });
  }

  ngOnDestroy(): void {
    this.alive = false;
  }

  onAddToCart(): void {
    this.addToCart.emit(this.product);
  }
}
```

### 2. **Component Naming** ✅

```typescript
// ✅ CORRECT - Descriptive, hierarchical naming
ProductListComponent
ProductCardComponent
ProductQuickViewComponent
CustomerAccountSettingsComponent
ShoppingCartSummaryComponent

// ❌ INCORRECT - Generic or unclear naming
ListComponent
CardComponent
ModalComponent
PageComponent
```

### 3. **Template Patterns** ✅

Use Angular template best practices:

```html
<!-- ✅ CORRECT - Semantic HTML with Angular patterns -->
<article class="product-card" [class.product-card--featured]="product.isFeatured">
  <header class="product-card__header">
    <img
      class="product-card__image"
      [src]="product.imageUrl"
      [alt]="product.name"
      loading="lazy">
  </header>

  <div class="product-card__content">
    <h3 class="product-card__title">{{ product.name }}</h3>
    <p class="product-card__price">
      {{ product.price | currency:siteConfig.currency:'symbol':'1.2-2' }}
    </p>
  </div>

  <footer class="product-card__actions">
    <button
      type="button"
      class="btn btn-primary"
      [disabled]="!product.inStock"
      (click)="onAddToCart()"
      [attr.aria-label]="'Add ' + product.name + ' to cart'">
      {{ 'SHOP.ADD_TO_CART' | translate }}
    </button>
  </footer>
</article>
```

## Service Layer Standards

### 1. **Service Architecture** ✅

```typescript
// ✅ CORRECT - Injectable service with proper error handling
@Injectable({
  providedIn: 'root'
})
export class ProductService {
  private apiUrl = environment.apiUrl;
  private productUpdatedSubject = new Subject<Product>();

  public productUpdated$ = this.productUpdatedSubject.asObservable();

  constructor(
    private http: HttpClient,
    private oesConfig: OesConfigService
  ) {}

  getProducts(params: ProductSearchParams): Observable<ProductResponse> {
    const url = `${this.apiUrl}/products`;
    return this.http.get<ProductResponse>(url, { params: this.buildParams(params) })
      .pipe(
        map(response => this.transformProductResponse(response)),
        catchError(this.handleError<ProductResponse>('getProducts'))
      );
  }

  getProduct(id: string): Observable<Product> {
    const url = `${this.apiUrl}/products/${id}`;
    return this.http.get<Product>(url)
      .pipe(
        map(product => this.transformProduct(product)),
        catchError(this.handleError<Product>('getProduct'))
      );
  }

  private handleError<T>(operation = 'operation', result?: T) {
    return (error: any): Observable<T> => {
      console.error(`${operation} failed:`, error);

      // Send error to logging service
      // this.logService.error(operation, error);

      // Return safe fallback result
      return of(result as T);
    };
  }

  private transformProduct(apiProduct: any): Product {
    return {
      id: apiProduct.id,
      name: apiProduct.name,
      price: apiProduct.price,
      imageUrl: apiProduct.imageUrl || '/assets/images/product-placeholder.jpg',
      inStock: apiProduct.stock > 0,
      // ... other transformations
    };
  }
}
```

### 2. **HTTP Interceptors** ✅

Use interceptors for cross-cutting concerns:

```typescript
// ✅ CORRECT - Authentication interceptor
@Injectable()
export class AuthInterceptor implements HttpInterceptor {
  constructor(private oesConfig: OesConfigService) {}

  intercept(req: HttpRequest<any>, next: HttpHandler): Observable<HttpEvent<any>> {
    // Add authentication headers
    const authReq = req.clone({
      setHeaders: {
        'Authorization': `Bearer ${this.oesConfig.authToken}`,
        'Merchant-Id': this.oesConfig.merchantId
      }
    });

    return next.handle(authReq);
  }
}
```

## State Management

### 1. **Local Component State** ✅

For simple component state, use component properties:

```typescript
// ✅ CORRECT - Simple component state
export class ProductListComponent {
  products: Product[] = [];
  loading = false;
  currentPage = 1;
  totalPages = 0;

  loadProducts(): void {
    this.loading = true;
    this.productService.getProducts({ page: this.currentPage })
      .subscribe(response => {
        this.products = response.products;
        this.totalPages = response.totalPages;
        this.loading = false;
      });
  }
}
```

### 2. **Shared State with Services** ✅

For shared state across components, use services with BehaviorSubject:

```typescript
// ✅ CORRECT - Shared cart state
@Injectable({ providedIn: 'root' })
export class CartService {
  private cartItemsSubject = new BehaviorSubject<CartItem[]>([]);
  private cartTotalSubject = new BehaviorSubject<number>(0);

  public cartItems$ = this.cartItemsSubject.asObservable();
  public cartTotal$ = this.cartTotalSubject.asObservable();
  public cartCount$ = this.cartItems$.pipe(
    map(items => items.reduce((count, item) => count + item.quantity, 0))
  );

  addItem(product: Product, quantity: number = 1): void {
    const currentItems = this.cartItemsSubject.value;
    const existingItem = currentItems.find(item => item.productId === product.id);

    let newItems: CartItem[];
    if (existingItem) {
      newItems = currentItems.map(item =>
        item.productId === product.id
          ? { ...item, quantity: item.quantity + quantity }
          : item
      );
    } else {
      newItems = [...currentItems, { productId: product.id, product, quantity }];
    }

    this.cartItemsSubject.next(newItems);
    this.updateCartTotal(newItems);
  }

  private updateCartTotal(items: CartItem[]): void {
    const total = items.reduce((sum, item) => sum + (item.product.price * item.quantity), 0);
    this.cartTotalSubject.next(total);
  }
}
```

## Internationalization (i18n)

### 1. **Translation Structure** ✅

Organize translations by feature and maintain consistency:

```typescript
// ✅ CORRECT - src/app/i18n/en-gb.ts
export const oesLocaleEn = {
  lang: 'en-gb',
  data: {
    COMMON: {
      LOADING: 'Loading...',
      ERROR: 'An error occurred',
      SAVE: 'Save',
      CANCEL: 'Cancel',
      DELETE: 'Delete',
      EDIT: 'Edit'
    },
    SHOP: {
      PRODUCTS: 'Products',
      ADD_TO_CART: 'Add to Cart',
      VIEW_DETAILS: 'View Details',
      OUT_OF_STOCK: 'Out of Stock',
      PRICE_FROM: 'From {{price}}',
      FILTERS: {
        CATEGORY: 'Category',
        PRICE_RANGE: 'Price Range',
        BRAND: 'Brand',
        CLEAR_ALL: 'Clear All Filters'
      }
    },
    ACCOUNT: {
      LOGIN: 'Login',
      REGISTER: 'Register',
      PROFILE: 'Profile',
      ORDERS: 'Orders',
      ADDRESSES: 'Addresses'
    }
  }
};
```

### 2. **Translation Usage** ✅

```html
<!-- ✅ CORRECT - Translation usage in templates -->
<h1>{{ 'SHOP.PRODUCTS' | translate }}</h1>
<p>{{ 'SHOP.PRICE_FROM' | translate:{ price: product.price | currency } }}</p>

<!-- ✅ CORRECT - Pluralization -->
<span>{{ 'SHOP.ITEMS_COUNT' | translate:{ count: cartCount } }}</span>
```

```typescript
// ✅ CORRECT - Translation in components
constructor(private translate: TranslateService) {}

showSuccessMessage(): void {
  const message = this.translate.instant('SHOP.ADDED_TO_CART', {
    productName: this.product.name
  });
  this.toastr.success(message);
}
```

## Performance Optimization

### 1. **Change Detection Strategy** ✅

Use OnPush change detection for better performance:

```typescript
// ✅ CORRECT - OnPush change detection
@Component({
  selector: 'oes-product-list',
  templateUrl: './product-list.component.html',
  changeDetection: ChangeDetectionStrategy.OnPush
})
export class ProductListComponent {
  @Input() products: Product[];

  constructor(private cdr: ChangeDetectorRef) {}

  trackByProductId(index: number, product: Product): string {
    return product.id;
  }
}
```

### 2. **Lazy Loading** ✅

```typescript
// ✅ CORRECT - Lazy loaded routes
const routes: Routes = [
  {
    path: 'shop',
    loadChildren: () => import('./shop/shop.module').then(m => m.ShopModule)
  },
  {
    path: 'account',
    loadChildren: () => import('./account/account.module').then(m => m.AccountModule)
  }
];
```

### 3. **Image Optimization** ✅

```html
<!-- ✅ CORRECT - Optimized images -->
<img
  [src]="product.imageUrl"
  [alt]="product.name"
  loading="lazy"
  [style.aspect-ratio]="'1'"
  class="product-image">
```

## SSR (Server-Side Rendering)

### 1. **Platform Detection** ✅

```typescript
// ✅ CORRECT - Platform-aware code
import { isPlatformBrowser } from '@angular/common';

@Component({...})
export class AppComponent {
  constructor(@Inject(PLATFORM_ID) private platformId: any) {}

  ngAfterViewInit(): void {
    if (isPlatformBrowser(this.platformId)) {
      // Browser-only code
      this.initializeClientSideFeatures();
    }
  }
}
```

### 2. **Safe DOM Manipulation** ✅

```typescript
// ✅ CORRECT - Safe DOM access
@Injectable()
export class DocumentService {
  constructor(@Inject(DOCUMENT) private document: Document) {}

  getElementById(id: string): HTMLElement | null {
    return this.document?.getElementById(id) || null;
  }
}
```

## Testing Standards

### 1. **Component Testing** ✅

```typescript
// ✅ CORRECT - Component test with proper setup
describe('ProductCardComponent', () => {
  let component: ProductCardComponent;
  let fixture: ComponentFixture<ProductCardComponent>;
  let productService: jasmine.SpyObj<ProductService>;

  beforeEach(async () => {
    const productServiceSpy = jasmine.createSpyObj('ProductService', ['getProduct']);

    await TestBed.configureTestingModule({
      declarations: [ProductCardComponent],
      providers: [
        { provide: ProductService, useValue: productServiceSpy }
      ],
      schemas: [NO_ERRORS_SCHEMA]
    }).compileComponents();

    productService = TestBed.inject(ProductService) as jasmine.SpyObj<ProductService>;
  });

  beforeEach(() => {
    fixture = TestBed.createComponent(ProductCardComponent);
    component = fixture.componentInstance;
    component.product = createMockProduct();
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });

  it('should emit addToCart event when button clicked', () => {
    spyOn(component.addToCart, 'emit');

    const button = fixture.debugElement.query(By.css('.add-to-cart-btn'));
    button.triggerEventHandler('click', null);

    expect(component.addToCart.emit).toHaveBeenCalledWith(component.product);
  });
});
```

## Error Handling

### 1. **Global Error Handler** ✅

```typescript
// ✅ CORRECT - Global error handler
@Injectable()
export class GlobalErrorHandler implements ErrorHandler {
  constructor(private notificationService: NotificationService) {}

  handleError(error: any): void {
    console.error('Global error caught:', error);

    if (error instanceof HttpErrorResponse) {
      this.handleHttpError(error);
    } else {
      this.handleClientError(error);
    }
  }

  private handleHttpError(error: HttpErrorResponse): void {
    if (error.status === 401) {
      // Redirect to login
    } else if (error.status >= 500) {
      this.notificationService.showError('Server error occurred');
    }
  }

  private handleClientError(error: Error): void {
    this.notificationService.showError('An unexpected error occurred');
  }
}
```

## Security Standards

### 1. **XSS Prevention** ✅

```typescript
// ✅ CORRECT - Safe HTML handling
@Component({
  template: `
    <!-- Safe - Angular automatically escapes -->
    <p>{{ userInput }}</p>

    <!-- Safe - Sanitized HTML -->
    <div [innerHTML]="sanitizedHtml"></div>
  `
})
export class SafeComponent {
  constructor(private sanitizer: DomSanitizer) {}

  get sanitizedHtml(): SafeHtml {
    return this.sanitizer.sanitize(SecurityContext.HTML, this.rawHtml) || '';
  }
}
```

### 2. **Authentication Guards** ✅

```typescript
// ✅ CORRECT - Route protection
@Injectable()
export class AuthGuard implements CanActivate {
  constructor(
    private authService: AuthService,
    private router: Router
  ) {}

  canActivate(): boolean {
    if (this.authService.isLoggedIn()) {
      return true;
    }

    this.router.navigate(['/account/login']);
    return false;
  }
}
```

## Build and Deployment

### 1. **Environment Configuration** ✅

```typescript
// ✅ CORRECT - Environment-specific configs
export const environment = {
  production: true,
  apiUrl: 'https://api.oelite.com',
  merchantId: 'YOUR_MERCHANT_ID',
  features: {
    enableSSR: true,
    enableI18n: true,
    enableAnalytics: true
  }
};
```

### 2. **Build Scripts** ✅

```json
// ✅ CORRECT - package.json scripts
{
  "scripts": {
    "start": "ng serve --disable-host-check --configuration=development",
    "build": "ng build",
    "build:prod": "ng build --configuration=production",
    "build:ssr": "ng build --configuration=production && ng run oes:server",
    "serve:ssr": "node dist/server",
    "lint": "ng lint",
    "test": "ng test --watch=false --browsers=ChromeHeadless"
  }
}
```

## Common Anti-Patterns to Avoid

### 1. **Subscription Management** ❌

```typescript
// ❌ FORBIDDEN - Memory leaks
export class BadComponent implements OnInit {
  ngOnInit(): void {
    this.dataService.getData().subscribe(data => {
      // No unsubscription - memory leak!
    });
  }
}

// ✅ CORRECT - Proper cleanup
export class GoodComponent implements OnInit, OnDestroy {
  private alive = true;

  ngOnInit(): void {
    this.dataService.getData()
      .pipe(takeWhile(() => this.alive))
      .subscribe(data => {
        // Properly managed subscription
      });
  }

  ngOnDestroy(): void {
    this.alive = false;
  }
}
```

### 2. **Direct DOM Manipulation** ❌

```typescript
// ❌ FORBIDDEN - Direct DOM access
ngAfterViewInit(): void {
  document.getElementById('myElement').style.color = 'red';
}

// ✅ CORRECT - Angular way
@ViewChild('myElement', { static: true }) myElement: ElementRef;

ngAfterViewInit(): void {
  this.renderer.setStyle(this.myElement.nativeElement, 'color', 'red');
}
```

## Validation Rules

### 1. **Compilation Checks**
- All components must implement proper lifecycle interfaces
- Services must be properly injected with `@Injectable()`
- Modules must follow lazy loading patterns for features
- All templates must use proper Angular syntax

### 2. **Runtime Checks**
- No memory leaks from unsubscribed observables
- Proper error boundaries and fallback states
- Accessibility compliance (WCAG 2.1 AA)
- Performance monitoring for route changes

### 3. **Code Quality Checks**
- ESLint compliance with Angular-specific rules
- Proper TypeScript typing (no `any` types)
- Unit test coverage above 80%
- Proper documentation for public APIs

---

**Next Steps**: Review existing Angular components and migrate any patterns that don't follow these standards. Implement ESLint rules to enforce these patterns automatically.