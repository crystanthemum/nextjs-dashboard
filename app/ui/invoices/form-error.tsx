"use client";

const FormError = ({ errorKey }: { errorKey: string[] }) => {
  return (
    <div id="customer-error" aria-live="polite" aria-atomic="true">
      <p className="mt-2 text-sm text-red">{errorKey}</p>
    </div>
  );
};

export default FormError;
