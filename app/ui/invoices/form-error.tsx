"use client";

const FormError = (errorKey: string[]) => {
  return (
    <div id="customer-error" aria-live="polite" aria-atomic="true">
      <p className="mt-2 text-sm text-red">{[...Object.values(errorKey)]}</p>
    </div>
  );
};

export default FormError;
