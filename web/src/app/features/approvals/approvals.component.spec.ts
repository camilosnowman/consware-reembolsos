import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Reimbursement } from '../../models/reimbursement.model';
import { ApprovalsComponent } from './approvals.component';

const BASE_URL = 'http://localhost:5000/api/reimbursements';

describe('ApprovalsComponent', () => {
  let fixture: ComponentFixture<ApprovalsComponent>;
  let component: ApprovalsComponent;
  let compiled: HTMLElement;
  let httpMock: HttpTestingController;

  const pendingItem: Reimbursement = {
    id: 7,
    employeeName: 'Ana Torres',
    amount: 120000,
    category: 'Transporte',
    description: 'Taxi al aeropuerto',
    status: 'Pending',
    rejectionReason: null,
    createdAtUtc: '2026-11-05T10:00:00Z',
    decidedAtUtc: null,
  };

  const approvedItem: Reimbursement = {
    ...pendingItem,
    id: 8,
    employeeName: 'Luis Gómez',
    status: 'Approved',
    decidedAtUtc: '2026-11-05T12:00:00Z',
  };

  const expectPendingLoad = (): void => {
    const req = httpMock.expectOne(
      (r) => r.method === 'GET' && r.url === BASE_URL && r.params.get('status') === 'Pending',
    );
    req.flush([pendingItem, approvedItem]);
  };

  const openRejectModal = (): void => {
    compiled.querySelector<HTMLButtonElement>('button.btn-reject')!.click();
    fixture.detectChanges();
  };

  const setReason = (value: string): void => {
    const textarea = compiled.querySelector<HTMLTextAreaElement>('#reason')!;
    textarea.value = value;
    textarea.dispatchEvent(new Event('input'));
    fixture.detectChanges();
  };

  const getSubmitButton = (): HTMLButtonElement =>
    compiled.querySelector<HTMLButtonElement>('.modal-actions button[type="submit"]')!;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [ApprovalsComponent],
      providers: [provideHttpClient(), provideHttpClientTesting()],
    }).compileComponents();

    httpMock = TestBed.inject(HttpTestingController);
    fixture = TestBed.createComponent(ApprovalsComponent);
    component = fixture.componentInstance;
    compiled = fixture.nativeElement as HTMLElement;
    fixture.detectChanges();
  });

  afterEach(() => {
    httpMock.verify();
  });

  it('carga por defecto con el filtro Pending y muestra la lista devuelta', () => {
    expectPendingLoad();
    fixture.detectChanges();

    const filter = compiled.querySelector<HTMLSelectElement>('#filter');
    expect(filter?.value).toBe('Pending');

    const rows = compiled.querySelectorAll('tbody tr');
    expect(rows.length).toBe(2);
    expect(rows[0].textContent).toContain('Ana Torres');
    expect(rows[0].textContent).toContain('Aprobar');
    expect(rows[1].textContent).toContain('Luis Gómez');
  });

  it('al cambiar el filtro a Todas pide la lista completa sin el parámetro status', () => {
    expectPendingLoad();
    fixture.detectChanges();

    const filter = compiled.querySelector<HTMLSelectElement>('#filter')!;
    filter.value = 'All';
    filter.dispatchEvent(new Event('change'));

    const req = httpMock.expectOne(
      (r) => r.method === 'GET' && r.url === BASE_URL && r.params.get('status') === null,
    );
    req.flush([pendingItem]);
    fixture.detectChanges();

    expect(component.filter()).toBe('All');
    expect(compiled.querySelectorAll('tbody tr').length).toBe(1);
  });

  it('bloquea el rechazo con motivo vacío o solo espacios sin enviar HTTP', () => {
    expectPendingLoad();
    fixture.detectChanges();
    openRejectModal();

    expect(compiled.querySelector('.modal')).toBeTruthy();

    setReason('');
    expect(getSubmitButton().disabled).toBe(true);

    setReason('   ');
    expect(getSubmitButton().disabled).toBe(true);
    expect(compiled.querySelector('.field-error')?.textContent).toContain(
      'El motivo es obligatorio',
    );

    getSubmitButton().click();
    component.confirmReject();

    expect(httpMock.match((r) => r.method === 'PATCH')).toEqual([]);
    expect(httpMock.match((r) => r.url === BASE_URL)).toEqual([]);
  });

  it('bloquea motivos que superan la longitud máxima de 500 caracteres', () => {
    expectPendingLoad();
    fixture.detectChanges();
    openRejectModal();

    setReason(`${'a'.repeat(500)}`);
    expect(getSubmitButton().disabled).toBe(false);

    setReason(`${'a'.repeat(501)}`);
    expect(getSubmitButton().disabled).toBe(true);
    expect(compiled.querySelector('.field-error')?.textContent).toContain('500');

    component.confirmReject();
    expect(httpMock.match((r) => r.method === 'PATCH')).toEqual([]);
  });

  it('envía el motivo recortado (trim) al rechazar una solicitud válida', () => {
    expectPendingLoad();
    fixture.detectChanges();
    openRejectModal();

    setReason('  Falta la factura adjunta  ');
    expect(getSubmitButton().disabled).toBe(false);
    getSubmitButton().click();

    const req = httpMock.expectOne(
      (r) => r.method === 'PATCH' && r.url === `${BASE_URL}/${pendingItem.id}/reject`,
    );
    expect(req.request.body).toEqual({ reason: 'Falta la factura adjunta' });
    req.flush(null);

    const reload = httpMock.expectOne(
      (r) => r.method === 'GET' && r.url === BASE_URL && r.params.get('status') === 'Pending',
    );
    reload.flush([]);
    fixture.detectChanges();

    expect(compiled.querySelector('.modal')).toBeNull();
    expect(compiled.querySelector('.toast')?.textContent).toContain('Solicitud rechazada');
  });

  it('ante un conflicto 409 cierra el modal, avisa y recarga la lista', () => {
    expectPendingLoad();
    fixture.detectChanges();
    openRejectModal();

    setReason('Ya fue decidida por otro aprobador');
    getSubmitButton().click();

    const req = httpMock.expectOne(
      (r) => r.method === 'PATCH' && r.url === `${BASE_URL}/${pendingItem.id}/reject`,
    );
    req.flush({ message: 'La solicitud ya fue decidida.' }, { status: 409, statusText: 'Conflict' });

    const reload = httpMock.expectOne(
      (r) => r.method === 'GET' && r.url === BASE_URL && r.params.get('status') === 'Pending',
    );
    reload.flush([]);
    fixture.detectChanges();

    expect(compiled.querySelector('.modal')).toBeNull();
    expect(compiled.querySelector('.toast')?.textContent).toContain('ya fue decidida');
  });
});
